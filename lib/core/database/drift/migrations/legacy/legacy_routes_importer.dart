import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_route_source.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Legacy table names — frozen history, referenced in exactly one place.
class _Legacy {
  _Legacy._();

  static const depots = 'depots';
  static const routes = 'routes';
  static const stops = 'stops';
  static const locationSamples = 'location_samples';
  static const checkIns = 'checkins';
  static const checkOuts = 'checkouts';
  static const orders = 'visit_orders';
  static const stockUpdates = 'visit_stock_updates';
  static const returns = 'visit_returns';
  static const collections = 'visit_collections';
  static const notes = 'visit_notes';
  static const photos = 'visit_photos';
  static const fraudFlags = 'fraud_flags';
  static const syncMeta = 'sync_meta';

  /// Every table carrying business data, in FK-safe purge order (children
  /// first). `depots` is included: it is a denormalised copy the encrypted
  /// database already owns authoritatively.
  static const allDataTables = [
    photos,
    notes,
    collections,
    returns,
    stockUpdates,
    orders,
    checkOuts,
    checkIns,
    fraudFlags,
    locationSamples,
    stops,
    routes,
    depots,
    syncMeta,
  ];
}

/// What the import did. Returned rather than thrown so the caller can decide
/// whether the outcome justifies purging the plaintext source.
class LegacyImportResult {
  const LegacyImportResult({
    required this.imported,
    required this.skipped,
    required this.alreadyDone,
    required this.sourceMissing,
  });

  const LegacyImportResult.noop({required this.sourceMissing})
      : imported = const {},
        skipped = const {},
        alreadyDone = false;

  const LegacyImportResult.alreadyImported()
      : imported = const {},
        skipped = const {},
        alreadyDone = true,
        sourceMissing = false;

  /// Rows written, keyed by legacy table name.
  final Map<String, int> imported;

  /// Rows deliberately not written (orphans), keyed by legacy table name.
  final Map<String, int> skipped;

  final bool alreadyDone;
  final bool sourceMissing;

  int get totalImported => imported.values.fold<int>(0, (a, b) => a + b);
  int get totalSkipped => skipped.values.fold<int>(0, (a, b) => a + b);

  /// Only a clean run may be followed by a purge. An import that skipped rows
  /// is *not* clean: those rows exist only in the plaintext file, and deleting
  /// it would destroy them.
  ///
  /// A failed import cannot reach this getter — [LegacyRoutesImporter.import]
  /// rethrows after the transaction rolls back, so a result object only ever
  /// represents a run that completed.
  bool get safeToPurge => !sourceMissing && !alreadyDone && totalSkipped == 0;
}

/// Imports the legacy plaintext `routes.db` into the single encrypted database
/// (ADR-001, `docs/blueprint/migration-plan.md` **T1.5** — the live Sprint-1 P0).
///
/// This is the highest-risk step in the whole migration plan: it is a one-way,
/// on-device data move, and the data it moves (depot PII, GPS traces of named
/// employees, uncollected payments) is both sensitive and irreplaceable. The
/// design follows from that:
///
/// - **Idempotent.** Every write is an upsert keyed by the legacy UUID, and a
///   completion marker in `app_metadata` short-circuits re-runs. A device that
///   dies mid-import and restarts re-runs it safely rather than double-applying
///   (`docs/blueprint/local-storage-architecture.md` §5).
/// - **One transaction.** Either the whole import lands or none of it does —
///   impossible before ADR-001, when the data spanned two database files.
/// - **Reconciles, never blind-copies.** The legacy `depots` table is a
///   denormalised copy of a table the encrypted database already owns; it is
///   dropped, not imported, and only its two unique fields are absorbed.
/// - **Never purges on its own.** [LegacyImportResult.safeToPurge] is advice to
///   the caller; deleting the plaintext source is a separate, explicit decision.
class LegacyRoutesImporter {
  LegacyRoutesImporter({
    required AppDatabase db,
    required LegacyRouteSource source,
    required AppLogger logger,
  })  : _db = db,
        _source = source,
        _logger = logger;

  final AppDatabase _db;
  final LegacyRouteSource _source;
  final AppLogger _logger;

  /// `app_metadata` key marking a completed import, so it runs at most once.
  static const String importedAtKey = 'migration.routes_db.imported_at';

  Future<LegacyImportResult> import() async {
    if (await _db.appMetadataDao.getValue(importedAtKey) != null) {
      _logger.info('legacy_import.skipped', fields: {'reason': 'already_done'});
      return const LegacyImportResult.alreadyImported();
    }
    if (!await _source.exists()) {
      // Fresh install: nothing to migrate. Mark it done so a later
      // reinstall-with-restore can't re-trigger an import of stale data.
      await _markDone();
      _logger.info('legacy_import.skipped', fields: {'reason': 'no_source'});
      return const LegacyImportResult.noop(sourceMissing: true);
    }

    final imported = <String, int>{};
    final skipped = <String, int>{};

    try {
      await _db.transaction(() async {
        await _absorbDepotAttributes(imported, skipped);
        final routeIds = await _importRoutes(imported);
        final stopIds = await _importStops(imported, skipped, routeIds);
        await _importTelemetry(imported, skipped, routeIds, stopIds);
        await _importCaptures(imported, skipped, stopIds);
        await _importSyncMeta(imported);
        await _markDone();
      });
    } catch (error, stackTrace) {
      // The transaction rolled back — the encrypted database is untouched and
      // the plaintext source is intact, so a retry is safe. Surface it rather
      // than reporting a success the caller might act on by purging.
      _logger.error('legacy_import.failed',
          error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      await _source.close();
    }

    // §10: counts only. Never the rows themselves — they are depot PII and
    // GPS traces.
    _logger.info('legacy_import.completed', fields: {
      'importedTotal': imported.values.fold<int>(0, (a, b) => a + b),
      'skippedTotal': skipped.values.fold<int>(0, (a, b) => a + b),
    });

    return LegacyImportResult(
      imported: imported,
      skipped: skipped,
      alreadyDone: false,
      sourceMissing: false,
    );
  }

  /// Absorbs `territory_type` / `geofence_radius_override` onto depots the
  /// directory already knows.
  ///
  /// The legacy row is **not** imported as a depot. `depots` in the
  /// encrypted database is SAP-controlled — "overwritten wholesale on every
  /// sync, never merged locally" — and the legacy copy carries neither
  /// `sap_depot_id` nor credit/status. Writing it back would resurrect stale
  /// PII and clobber authoritative columns.
  Future<void> _absorbDepotAttributes(
    Map<String, int> imported,
    Map<String, int> skipped,
  ) async {
    var applied = 0;
    var unknown = 0;
    for (final row in await _source.readTable(_Legacy.depots)) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final updated = await _db.routeDao.upsertRouteAttributesOnDepot(
        id,
        territoryType: row['territory_type'] as String?,
        geofenceRadiusOverride: _toDouble(row['geofence_radius_override']),
      );
      updated > 0 ? applied++ : unknown++;
    }
    imported[_Legacy.depots] = applied;
    // Not an orphan risk: a depot the directory lacks will simply be pulled
    // on the next depot sync, which is authoritative anyway.
    skipped[_Legacy.depots] = unknown;
  }

  Future<Set<String>> _importRoutes(Map<String, int> imported) async {
    final ids = <String>{};
    for (final row in await _source.readTable(_Legacy.routes)) {
      final id = row['id'] as String?;
      if (id == null) continue;
      await _db.into(_db.routes).insertOnConflictUpdate(
            RoutesCompanion.insert(
              id: id,
              name: _str(row['name']),
              repId: _str(row['rep_id']),
              repName: _str(row['rep_name']),
              territory: _str(row['territory']),
              visitDate: _dt(row['visit_date'])!,
              plannedStart: _dt(row['planned_start'])!,
              plannedEnd: _dt(row['planned_end'])!,
              status: _str(row['status']),
              // A route plan is SAP-owned and was already pulled once; it is not
              // a local capture awaiting push.
              syncState: const Value(SyncStates.synced),
              dirty: const Value(false),
            ),
          );
      ids.add(id);
    }
    imported[_Legacy.routes] = ids.length;
    return ids;
  }

  /// Imports stops, skipping any whose depot or route is unknown.
  ///
  /// `route_stops.depot_id` is a real FK now (ADR-001). A blind copy would
  /// throw and roll back the entire import because of one stale row, so orphans
  /// are counted and skipped instead — and a non-zero skip count blocks the
  /// purge, because those rows would otherwise be destroyed with the file.
  Future<Set<String>> _importStops(
    Map<String, int> imported,
    Map<String, int> skipped,
    Set<String> routeIds,
  ) async {
    final ids = <String>{};
    var orphans = 0;
    for (final row in await _source.readTable(_Legacy.stops)) {
      final id = row['id'] as String?;
      final routeId = row['route_id'] as String?;
      final depotId = row['depot_id'] as String?;
      if (id == null || routeId == null || depotId == null) {
        orphans++;
        continue;
      }
      if (!routeIds.contains(routeId) ||
          !await _db.routeDao.depotExists(depotId)) {
        orphans++;
        _logger.warning('legacy_import.orphan_stop', fields: {
          // §10: no depot identifiers in logs.
          'reason':
              routeIds.contains(routeId) ? 'unknown_depot' : 'unknown_route',
        });
        continue;
      }
      await _db.into(_db.routeStops).insertOnConflictUpdate(
            RouteStopsCompanion.insert(
              id: id,
              routeId: routeId,
              depotId: depotId,
              sequence: _toInt(row['sequence']) ?? 0,
              // Nullable since v25, and passed through rather than forced:
              // the `!` here used to throw on a legacy row whose window was
              // blank, which aborted the whole import for one bad stop.
              plannedArrival: Value(_dt(row['planned_arrival'])),
              plannedDeparture: Value(_dt(row['planned_departure'])),
              status: _str(row['status']),
              actualArrival: Value(_dt(row['actual_arrival'])),
              actualDeparture: Value(_dt(row['actual_departure'])),
              // Execution status IS a local capture — it must still reach SAP.
              syncState: const Value(SyncStates.dirty),
              dirty: const Value(true),
            ),
          );
      ids.add(id);
    }
    imported[_Legacy.stops] = ids.length;
    skipped[_Legacy.stops] = orphans;
    return ids;
  }

  Future<void> _importTelemetry(
    Map<String, int> imported,
    Map<String, int> skipped,
    Set<String> routeIds,
    Set<String> stopIds,
  ) async {
    var samples = 0;
    var samplesSkipped = 0;
    for (final row in await _source.readTable(_Legacy.locationSamples)) {
      final id = row['id'] as String?;
      final routeId = row['route_id'] as String?;
      if (id == null || routeId == null || !routeIds.contains(routeId)) {
        samplesSkipped++;
        continue;
      }
      await _db.into(_db.locationSamples).insertOnConflictUpdate(
            LocationSamplesCompanion.insert(
              id: id,
              routeId: routeId,
              latitude: _toDouble(row['latitude']) ?? 0,
              longitude: _toDouble(row['longitude']) ?? 0,
              accuracy: _toDouble(row['accuracy']) ?? 0,
              speed: _toDouble(row['speed']) ?? 0,
              heading: _toDouble(row['heading']) ?? 0,
              altitude: _toDouble(row['altitude']) ?? 0,
              timestamp: _dt(row['timestamp'])!,
              isMocked: Value(_toBool(row['is_mocked'])),
            ),
          );
      samples++;
    }
    imported[_Legacy.locationSamples] = samples;
    skipped[_Legacy.locationSamples] = samplesSkipped;

    var flags = 0;
    var flagsSkipped = 0;
    for (final row in await _source.readTable(_Legacy.fraudFlags)) {
      final id = row['id'] as String?;
      final routeId = row['route_id'] as String?;
      if (id == null || routeId == null || !routeIds.contains(routeId)) {
        flagsSkipped++;
        continue;
      }
      final stopId = row['stop_id'] as String?;
      await _db.into(_db.fraudFlags).insertOnConflictUpdate(
            FraudFlagsCompanion.insert(
              id: id,
              routeId: routeId,
              // Drop a dangling stop reference rather than the whole flag: a
              // fraud signal is evidence and must survive the migration.
              stopId: Value(stopIds.contains(stopId) ? stopId : null),
              type: _str(row['type']),
              detail: _str(row['detail']),
              timestamp: _dt(row['timestamp'])!,
              blocked: Value(_toBool(row['blocked'])),
            ),
          );
      flags++;
    }
    imported[_Legacy.fraudFlags] = flags;
    skipped[_Legacy.fraudFlags] = flagsSkipped;
  }

  Future<void> _importCaptures(
    Map<String, int> imported,
    Map<String, int> skipped,
    Set<String> stopIds,
  ) async {
    Future<void> each(
      String table,
      Future<void> Function(Map<String, Object?> row, String stopId) write,
    ) async {
      var ok = 0;
      var bad = 0;
      for (final row in await _source.readTable(table)) {
        final stopId = row['stop_id'] as String?;
        if (row['id'] == null || stopId == null || !stopIds.contains(stopId)) {
          bad++;
          continue;
        }
        await write(row, stopId);
        ok++;
      }
      imported[table] = ok;
      skipped[table] = bad;
    }

    await each(_Legacy.checkIns, (row, stopId) async {
      await _db.into(_db.visitCheckIns).insertOnConflictUpdate(
            VisitCheckInsCompanion.insert(
              id: _str(row['id']),
              stopId: stopId,
              timestamp: _dt(row['timestamp'])!,
              latitude: _toDouble(row['latitude']) ?? 0,
              longitude: _toDouble(row['longitude']) ?? 0,
              accuracy: _toDouble(row['accuracy']) ?? 0,
              distanceFromDepot: _toDouble(row['distance_from_depot']) ?? 0,
              isMocked: Value(_toBool(row['is_mocked'])),
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });

    await each(_Legacy.checkOuts, (row, stopId) async {
      await _db.into(_db.visitCheckOuts).insertOnConflictUpdate(
            VisitCheckOutsCompanion.insert(
              id: _str(row['id']),
              stopId: stopId,
              timestamp: _dt(row['timestamp'])!,
              latitude: _toDouble(row['latitude']) ?? 0,
              longitude: _toDouble(row['longitude']) ?? 0,
              durationMinutes: _toInt(row['duration_minutes']) ?? 0,
              visitSummary: _str(row['visit_summary']),
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });

    await each(_Legacy.orders, (row, stopId) async {
      await _db.into(_db.visitOrderLines).insertOnConflictUpdate(
            VisitOrderLinesCompanion.insert(
              id: _str(row['id']),
              stopId: stopId,
              productId: _str(row['product_id']),
              productName: _str(row['product_name']),
              quantity: _toDouble(row['quantity']) ?? 0,
              unit: _str(row['unit']),
              unitPrice: _toDouble(row['unit_price']) ?? 0,
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });

    await each(_Legacy.stockUpdates, (row, stopId) async {
      // Legacy plaintext rows carried a raw `counted_quantity`; the encrypted
      // schema (v10) stores a three-tier `stock_level`. Same conservative
      // mapping as the v10 stepwise migration: 0 → low, positive → medium.
      final countedQuantity = _toDouble(row['counted_quantity']) ?? 0;
      await _db.into(_db.visitStockUpdates).insertOnConflictUpdate(
            VisitStockUpdatesCompanion.insert(
              id: _str(row['id']),
              stopId: Value(stopId),
              productId: _str(row['product_id']),
              productName: _str(row['product_name']),
              stockLevel: countedQuantity <= 0 ? 'low' : 'medium',
              notes: Value(_str(row['notes'])),
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });

    await each(_Legacy.returns, (row, stopId) async {
      await _db.into(_db.visitReturns).insertOnConflictUpdate(
            VisitReturnsCompanion.insert(
              id: _str(row['id']),
              stopId: stopId,
              productId: _str(row['product_id']),
              productName: _str(row['product_name']),
              quantity: _toDouble(row['quantity']) ?? 0,
              reason: _str(row['reason']),
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });

    await each(_Legacy.collections, (row, stopId) async {
      await _db.into(_db.visitCollections).insertOnConflictUpdate(
            VisitCollectionsCompanion.insert(
              id: _str(row['id']),
              stopId: stopId,
              amount: _toDouble(row['amount']) ?? 0,
              method: _str(row['method']),
              reference: Value(_str(row['reference'])),
              notes: Value(_str(row['notes'])),
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });

    await each(_Legacy.notes, (row, stopId) async {
      await _db.into(_db.visitNotes).insertOnConflictUpdate(
            VisitNotesCompanion.insert(
              id: _str(row['id']),
              stopId: stopId,
              type: _str(row['type']),
              body: _str(row['text']),
              createdAt: _dt(row['created_at'])!,
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });

    await each(_Legacy.photos, (row, stopId) async {
      await _db.into(_db.visitPhotos).insertOnConflictUpdate(
            VisitPhotosCompanion.insert(
              id: _str(row['id']),
              stopId: stopId,
              // Legacy column was `url`; the file itself stays on disk and is
              // not re-encrypted here — that is the Phase-5 file store.
              path: _str(row['url']),
              caption: Value(_str(row['caption'])),
              takenAt: _dt(row['taken_at'])!,
              isSignature: Value(_toBool(row['is_signature'])),
              syncState: _legacyState(row),
              dirty: _legacyDirty(row),
            ),
          );
    });
  }

  Future<void> _importSyncMeta(Map<String, int> imported) async {
    var count = 0;
    for (final row in await _source.readTable(_Legacy.syncMeta)) {
      final entity = row['entity'] as String?;
      if (entity == null) continue;
      final at = _dt(row['last_synced_at']);
      if (at != null) await _db.routeDao.setLastSyncedAt(entity, at);
      count++;
    }
    imported[_Legacy.syncMeta] = count;
  }

  Future<void> _markDone() => _db.appMetadataDao
      .setValue(importedAtKey, DateTime.now().toUtc().toIso8601String());

  /// Erases the plaintext rows. Caller must have verified
  /// [LegacyImportResult.safeToPurge] first — this method trusts that decision.
  ///
  /// Rows are deleted rather than the file unlinked: `routes.db` also holds
  /// `workflow_state`, which ADR-007 generalises in Phase 3 and which is still
  /// live. Deleting the file now would break resume. Emptying the business
  /// tables removes 100% of the PII, which is the actual security objective.
  Future<void> purgeLegacyData() async {
    for (final table in _Legacy.allDataTables) {
      await _source.deleteAllRows(table);
    }
    await _source.close();
    _logger.warning('legacy_import.purged', fields: {
      'tables': _Legacy.allDataTables.length,
    });
  }

  // ── Legacy value coercion ───────────────────────────────────────────
  // sqflite is untyped at the boundary: an INTEGER column can arrive as int,
  // a REAL as int, and dates were stored as ISO TEXT. These normalise without
  // ever letting a malformed legacy value throw mid-transaction.

  static Value<String> _legacyState(Map<String, Object?> row) =>
      Value(SyncStates.fromLegacy(row['sync_status'] as String?));

  static Value<bool> _legacyDirty(Map<String, Object?> row) =>
      Value(SyncStates.fromLegacy(row['sync_status'] as String?) !=
          SyncStates.synced);

  static String _str(Object? v) => v?.toString() ?? '';

  static DateTime? _dt(Object? v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    return DateTime.tryParse(v.toString())?.toUtc();
  }

  static double? _toDouble(Object? v) => switch (v) {
        null => null,
        final num n => n.toDouble(),
        _ => double.tryParse(v.toString()),
      };

  static int? _toInt(Object? v) => switch (v) {
        null => null,
        final num n => n.toInt(),
        _ => int.tryParse(v.toString()),
      };

  /// SQLite has no boolean: the legacy schema stored 0/1 INTEGER.
  static bool _toBool(Object? v) => switch (v) {
        null => false,
        final bool b => b,
        final num n => n != 0,
        _ => v.toString() == '1' || v.toString().toLowerCase() == 'true',
      };
}
