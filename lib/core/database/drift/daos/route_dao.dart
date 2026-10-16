import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/depots_table.dart';
import 'package:steelforce/core/database/drift/tables/route_tables.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';

part 'route_dao.g.dart';

/// A route plan plus its stops — the unit the sync upsert writes atomically.
///
/// Cross-table atomicity like this was structurally impossible under the old
/// three-plaintext-database split and is a named benefit of ADR-001.
class RouteWithStops {
  const RouteWithStops(this.route, this.stops);

  final RoutesCompanion route;
  final List<RouteStopsCompanion> stops;
}

/// A stop joined to the depot details the **route feed** supplied for it.
///
/// The domain's `RouteStop` embeds the whole depot record, not an id, so the
/// read has to join. It joins [RouteDepots] — the route feed's own flat
/// mirror — rather than the depot directory, because the two feeds are
/// separate endpoints with separate scopes and the directory routinely does not
/// have a stop's depot yet (ADR-011).
class RouteStopWithDepot {
  const RouteStopWithDepot(this.stop, this.depot);

  final RouteStopRow stop;

  /// Null when the route feed sent a stop without its depot row — rare, and
  /// deliberately **not** filtered out.
  ///
  /// The join is a LEFT join for exactly this reason. An inner join would drop
  /// the stop from the rep's day, which is the same data loss the foreign key
  /// used to cause, just silent instead of loud. The caller renders what it has
  /// (`docs/adr/ADR011localmirrornorelations.md`).
  final RouteDepotRow? depot;
}

/// Scoped accessor for the route aggregate: plans, stops, and the delta cursor.
///
/// Replaces the hand-written SQL in `my_visits/data/local/route_local_data_source.dart`
/// (ADR-004: generated DAOs give compile-time safety the raw-SQL version could
/// not). Reads exclude soft-deleted rows — a row pending a delete-push is still
/// on disk (`docs/blueprint/local-storage-architecture.md` §3.1) but must not be shown to the user.
@DriftAccessor(tables: [
  Routes,
  RouteStops,
  RouteDepots,
  RouteSyncMeta,
  AdHocVisitQueue,
  Depots
])
class RouteDao extends DatabaseAccessor<AppDatabase> with _$RouteDaoMixin {
  RouteDao(super.db);

  // ── Reads ───────────────────────────────────────────────────────────

  /// Routes planned for the calendar day containing [day].
  ///
  /// Compares against a half-open `[startOfDay, nextDay)` range rather than
  /// formatting a date string: `visit_date` is stored as an ISO-8601 UTC text
  /// column (`build.yaml`), so a string prefix match would break across
  /// timezones — exactly the ambiguity that build config exists to avoid.
  Future<List<RouteRow>> fetchRoutesForDay(DateTime day) {
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(routes)
          ..where((t) => t.deleted.equals(false))
          ..where((t) => t.visitDate.isBiggerOrEqualValue(start))
          ..where((t) => t.visitDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.plannedStart)]))
        .get();
  }

  Future<RouteRow?> getRoute(String routeId) => (select(routes)
        ..where((t) => t.id.equals(routeId))
        ..where((t) => t.deleted.equals(false)))
      .getSingleOrNull();

  /// Every locally-synced route regardless of date — feeds the calendar's
  /// per-day route-count dots and date-selection browsing, neither of which
  /// can be answered by [fetchRoutesForDay]'s single-day window.
  Future<List<RouteRow>> fetchAllRoutes() => (select(routes)
        ..where((t) => t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.visitDate)]))
      .get();

  /// Stops of a route in visit order.
  Future<List<RouteStopRow>> fetchStops(String routeId) => (select(routeStops)
        ..where((t) => t.routeId.equals(routeId))
        ..where((t) => t.deleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
      .get();

  /// Stops joined to the route feed's depot rows, in visit order.
  ///
  /// One join rather than N per-stop lookups: a route has dozens of stops and
  /// the per-stop variant is the N+1 pattern `playbook` §9 rejects.
  ///
  /// **A `leftOuterJoin`, and that matters.** It used to be an inner join
  /// against the depot *directory*, justified by `depot_id` being a
  /// non-null foreign key. That foreign key is gone (ADR-011) because it was
  /// destroying whole routes, and an inner join would have quietly inherited
  /// the same failure — a stop whose depot row had not arrived would vanish
  /// from the rep's day with no error anywhere. A left join keeps the stop and
  /// lets the caller decide how to render an unknown shop.
  Future<List<RouteStopWithDepot>> fetchStopsWithDepots(
    String routeId,
  ) async {
    final query = select(routeStops).join([
      leftOuterJoin(routeDepots, routeDepots.id.equalsExp(routeStops.depotId)),
    ])
      ..where(routeStops.routeId.equals(routeId))
      ..where(routeStops.deleted.equals(false))
      ..orderBy([OrderingTerm.asc(routeStops.sequence)]);

    final rows = await query.get();
    return rows
        .map((row) => RouteStopWithDepot(
              row.readTable(routeStops),
              row.readTableOrNull(routeDepots),
            ))
        .toList();
  }

  /// Reactive equivalent of [fetchRoutesForDay] — the UI rebuilds itself when
  /// a sync writes new plans, with no manual refresh
  /// (`docs/blueprint/offline-architecture.md` §1).
  Stream<List<RouteRow>> watchRoutesForDay(DateTime day) {
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(routes)
          ..where((t) => t.deleted.equals(false))
          ..where((t) => t.visitDate.isBiggerOrEqualValue(start))
          ..where((t) => t.visitDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.plannedStart)]))
        .watch();
  }

  // ── Local mutations (mark dirty; the repository enqueues the sync row) ──
  //
  // These set `dirty`/`sync_state` but deliberately do NOT enqueue sync work:
  // per ADR-003 point 3 and ADR-006, the repository decides "this mutation
  // needs to sync" and wraps the write + the queue insert in ONE transaction.
  // The DAO only has to be transaction-composable, not sync-aware.

  Future<void> updateRouteStatus(String routeId, String status) =>
      (update(routes)..where((t) => t.id.equals(routeId))).write(
        RoutesCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now().toUtc()),
          dirty: const Value(true),
          syncState: const Value(SyncStates.dirty),
        ),
      );

  Future<void> updateStopStatus(
    String stopId, {
    required String status,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  }) =>
      (update(routeStops)..where((t) => t.id.equals(stopId))).write(
        RouteStopsCompanion(
          status: Value(status),
          // Absent() rather than Value(null): omitting a field must leave the
          // stored value alone, not overwrite a recorded arrival with null.
          actualArrival: actualArrival == null
              ? const Value.absent()
              : Value(actualArrival),
          actualDeparture: actualDeparture == null
              ? const Value.absent()
              : Value(actualDeparture),
          updatedAt: Value(DateTime.now().toUtc()),
          dirty: const Value(true),
          syncState: const Value(SyncStates.dirty),
        ),
      );

  /// Puts a stop's execution back after the rep discarded the visit work
  /// that had not reached the server (Sync Center → Discard).
  ///
  /// Always clears the departure; clears the arrival too when
  /// [clearArrival] — the check-in itself was thrown away.
  ///
  /// The stop is left **clean**, not dirty: the local change it carried is
  /// gone, so the server's copy is the truth again and the next route pull
  /// may replace it (see [upsertRoutesWithStops]). Marking it dirty would pin
  /// the reset status on the device forever, since a stop row is never
  /// pushed on its own.
  ///
  /// Transaction-composable; the caller wraps it with the row deletes.
  Future<void> resetStopExecution(
    String stopId, {
    required String status,
    required bool clearArrival,
  }) =>
      (update(routeStops)..where((t) => t.id.equals(stopId))).write(
        RouteStopsCompanion(
          status: Value(status),
          actualArrival:
              clearArrival ? const Value(null) : const Value.absent(),
          actualDeparture: const Value(null),
          updatedAt: Value(DateTime.now().toUtc()),
          dirty: const Value(false),
          syncState: const Value(SyncStates.synced),
        ),
      );

  // ── Sync writes (pull) ──────────────────────────────────────────────

  /// Upserts routes and their stops in a single transaction.
  ///
  /// The **plan** is SAP-owned: sequence, planned times and depot come from the
  /// server, and a stop the server no longer sends has been removed from the
  /// plan and must not linger locally.
  ///
  /// The **execution** of a stop is not. Its status and actual arrival /
  /// departure are first-hand field captures (ADR-006 §5: client-authoritative
  /// for field captures), and a stop the rep checked in or completed offline is
  /// `dirty` until that progress is pushed. A pull used to delete and
  /// re-insert every stop, so the first route sync after an offline check-in
  /// reverted the stop to the server's older status — the local write that
  /// ADR-002 says must win simply vanished.
  ///
  /// So, per route, inside the one transaction:
  ///
  /// * a stop with **unpushed local progress** keeps its status, actual times,
  ///   `updated_at` and sync flags; the server's plan fields are still applied
  ///   to it. For a checked-in or checked-out stop that means *a check-in or
  ///   check-out row for it is still unsent* — once they are all accepted, the
  ///   server's copy is the truth and replaces the local one
  ///   (`check-in-check-out-mobile.md` §10). Any other local change (a skip,
  ///   an arrival) has no row of its own, so the stop's `dirty` flag decides;
  /// * a dirty stop the server no longer sends is **kept**, not deleted —
  ///   dropping it would discard the rep's unpushed progress;
  /// * every other stop is replaced by the server's copy, exactly as before.
  ///
  /// No foreign keys are involved (ADR-011): the depot need not exist in the
  /// directory for the stop to be stored.
  Future<void> upsertRoutesWithStops(List<RouteWithStops> items) {
    return transaction(() async {
      final unsentVisitStops = await _stopsWithUnsentVisitRows();
      for (final item in items) {
        await into(routes).insertOnConflictUpdate(item.route);
        final routeId = item.route.id.value;

        final localProgress = <String, RouteStopRow>{
          for (final row in await (select(routeStops)
                ..where((t) => t.routeId.equals(routeId)))
              .get())
            if (_hasUnpushedProgress(row, unsentVisitStops)) row.id: row,
        };

        await (delete(routeStops)
              ..where((t) => t.routeId.equals(routeId))
              ..where((t) => t.id.isNotIn(localProgress.keys)))
            .go();

        for (final stop in item.stops) {
          final local = localProgress.remove(stop.id.value);
          await into(routeStops).insertOnConflictUpdate(
            local == null ? stop : _keepLocalExecution(stop, local),
          );
        }
        // Whatever is left in `localProgress` is a dirty stop the server no
        // longer sends. It was not deleted above, so it simply stays.
      }
    });
  }

  /// True when [row] carries a local change the server has not confirmed.
  static bool _hasUnpushedProgress(
      RouteStopRow row, Set<String> unsentVisitStops) {
    if (!row.dirty && row.syncState == SyncStates.synced) return false;
    // A visit's progress travels in its check-in / check-out rows. When none
    // is waiting, the server has everything the local status was based on.
    if (row.status == 'checkedIn' || row.status == 'checkedOut') {
      return unsentVisitStops.contains(row.id);
    }
    return true;
  }

  /// Stops with a check-in or check-out still waiting to be sent. Raw SQL
  /// because those tables belong to the visit DAO; names are constants.
  Future<Set<String>> _stopsWithUnsentVisitRows() async {
    final rows = await customSelect(
      'SELECT stop_id FROM visit_check_ins WHERE sync_state = ? '
      'UNION SELECT stop_id FROM visit_check_outs WHERE sync_state = ?',
      variables: [
        Variable(SyncStates.dirty),
        Variable(SyncStates.dirty),
      ],
    ).get();
    return {for (final r in rows) r.read<String>('stop_id')};
  }

  /// The server's plan fields on [incoming], with [local]'s execution fields
  /// and sync state preserved.
  static RouteStopsCompanion _keepLocalExecution(
    RouteStopsCompanion incoming,
    RouteStopRow local,
  ) =>
      incoming.copyWith(
        status: Value(local.status),
        actualArrival: Value(local.actualArrival),
        actualDeparture: Value(local.actualDeparture),
        updatedAt: Value(local.updatedAt),
        dirty: Value(local.dirty),
        syncState: Value(local.syncState),
      );

  /// Stores the depot rows the route feed sent alongside the plans.
  ///
  /// Idempotent upsert keyed by depot id, so re-running a sync — which the
  /// backend explicitly permits, since a delta may re-send the full current set
  /// (`docs/feature/my-visits/api.md` §5.2) — converges rather than duplicating.
  ///
  /// This deliberately does **not** touch the `depots` directory. The two
  /// are different feeds with different scopes and different owners; writing
  /// one from the other is what produced the ordering dependency ADR-011
  /// removes, and `CLAUDE.md` §4 forbids a feature reaching into another
  /// feature's data anyway.
  Future<void> upsertRouteDepots(
    List<RouteDepotsCompanion> records,
  ) async {
    if (records.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(routeDepots, records));
  }

  /// Applies the two route-execution attributes onto an **existing** depot.
  ///
  /// The legacy `routes.db` kept its own denormalised `depots` table; T1.5
  /// drops it because [Depots] is the single source of truth (ADR-001) and is
  /// SAP-controlled — "overwritten wholesale on every sync, never merged
  /// locally". Route sync therefore may not create or overwrite a depot; it
  /// may only contribute the two fields the depot directory doesn't carry.
  ///
  /// Returns the number of rows updated: `0` means the depot directory has
  /// not synced this depot yet, which the caller should treat as "skip this
  /// stop", not as an error.
  Future<int> upsertRouteAttributesOnDepot(
    String depotId, {
    String? territoryType,
    double? geofenceRadiusOverride,
  }) =>
      (update(depots)..where((t) => t.id.equals(depotId))).write(
        DepotsCompanion(
          territoryType: territoryType == null
              ? const Value.absent()
              : Value(territoryType),
          geofenceRadiusOverride: geofenceRadiusOverride == null
              ? const Value.absent()
              : Value(geofenceRadiusOverride),
        ),
      );

  /// True when [depotId] exists in the directory — lets an import or sync
  /// skip orphan stops instead of triggering an FK violation.
  Future<bool> depotExists(String depotId) async {
    final row = await (select(depots)..where((t) => t.id.equals(depotId)))
        .getSingleOrNull();
    return row != null;
  }

  // ── Delta cursor ────────────────────────────────────────────────────

  Future<DateTime?> getLastSyncedAt(String entity) async {
    final row = await (select(routeSyncMeta)
          ..where((t) => t.entity.equals(entity)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> setLastSyncedAt(String entity, DateTime at) =>
      into(routeSyncMeta).insertOnConflictUpdate(
        RouteSyncMetaCompanion.insert(
          entity: entity,
          lastSyncedAt: Value(at),
        ),
      );

  // ── Ad hoc visits ───────────────────────────────────────────────────

  /// Writes the one stop and one depot an ad hoc create returned.
  ///
  /// Both in a single transaction: a stop whose depot row did not land renders
  /// as a placeholder card naming an id, which is worse than not appearing
  /// until the next sync.
  ///
  /// [route] is inserted **only when the route is genuinely absent**. A rep
  /// with no Call Plan for today has one opened for them server-side, so the
  /// stop can legitimately name a route this device has never seen — and a
  /// stop with no route header is invisible to the dashboard, which groups by
  /// route. The placeholder is replaced wholesale by the next sync.
  Future<void> upsertAdHocVisit({
    required RouteStopsCompanion stop,
    required RouteDepotsCompanion depot,
    required RoutesCompanion route,
  }) {
    return transaction(() async {
      await into(routeDepots).insertOnConflictUpdate(depot);

      final routeId = route.id.value;
      final existing = await (select(routes)
            ..where((t) => t.id.equals(routeId)))
          .getSingleOrNull();
      // `insertOnConflictUpdate` would overwrite a real synced route header
      // with the placeholder's blank rep and territory. Only insert when there
      // is nothing there.
      if (existing == null) await into(routes).insert(route);

      await into(routeStops).insertOnConflictUpdate(stop);
    });
  }

  /// The pending ad hoc requests, oldest first — the order they were tapped
  /// in, which is the order they should reach the server.
  Future<List<AdHocVisitQueueRow>> pendingAdHocVisits() =>
      (select(adHocVisitQueue)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<AdHocVisitQueueRow>> watchPendingAdHocVisits() =>
      (select(adHocVisitQueue)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// Persists a request **before** its first send.
  ///
  /// This ordering is the whole point: the `clientRequestId` has to survive a
  /// crash between the tap and the response, or the retry generates a new id
  /// and the server creates a second visit.
  Future<void> enqueueAdHocVisit(AdHocVisitQueueCompanion request) =>
      into(adHocVisitQueue).insertOnConflictUpdate(request);

  /// Records a failed attempt without dropping the request — same id, so the
  /// retry replays rather than duplicates.
  Future<void> markAdHocVisitAttempted(String id, {String? errorCode}) =>
      (update(adHocVisitQueue)..where((t) => t.id.equals(id))).write(
        AdHocVisitQueueCompanion(
          attempts: const Value.absent(),
          lastAttemptAt: Value(DateTime.now().toUtc()),
          lastErrorCode: Value(errorCode),
        ),
      );

  /// Drops a request that is finished — acknowledged by the server, replayed
  /// by it, or refused for a business reason that retrying cannot fix.
  Future<void> dequeueAdHocVisit(String id) =>
      (delete(adHocVisitQueue)..where((t) => t.id.equals(id))).go();

  /// True when today already holds a stop for [depotId], whatever put it
  /// there. Lets the depot picker hide shops that are already on the day
  /// rather than offering a tap that can only come back as a 409.
  Future<Set<String>> depotIdsOnDay(DateTime day) async {
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final query = select(routeStops).join([
      innerJoin(routes, routes.id.equalsExp(routeStops.routeId)),
    ])
      ..where(routes.deleted.equals(false))
      ..where(routeStops.deleted.equals(false))
      ..where(routes.visitDate.isBiggerOrEqualValue(start))
      ..where(routes.visitDate.isSmallerThanValue(end));
    final rows = await query.get();
    return {for (final row in rows) row.readTable(routeStops).depotId};
  }
}
