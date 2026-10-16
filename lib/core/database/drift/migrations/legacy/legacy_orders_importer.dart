import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/order_dao.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_routes_importer.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_sqlite_source.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/utils/typedefs.dart';

/// Legacy `catalog.db` table names — frozen history, referenced in one place.
class _Legacy {
  _Legacy._();

  static const quotations = 'quotations';
  static const salesOrders = 'sales_orders';
  static const syncQueue = 'sync_queue';

  /// Business tables in purge order. Product/catalog master data
  /// (`categories`, `products`, `prices`, `stock`, …) is deliberately **not**
  /// listed: it was already ported in T3/T4 and is re-syncable from SAP, so
  /// copying it would duplicate authoritative rows the encrypted database
  /// already owns.
  static const allDataTables = [syncQueue, salesOrders, quotations];
}

/// Imports the legacy plaintext `catalog.db` into the single encrypted database
/// (**T1.5b**), completing what T1.5 started for `routes.db`.
///
/// ## Why this exists at all
///
/// T1.5b moves quotations, sales orders, and the sync queue onto Drift tables.
/// Without an importer, that cutover would be silent data loss for every device
/// upgrading from a pre-T1.5b build: the app would open the new empty tables
/// and a rep's saved quotations — including work queued offline and not yet
/// pushed to SAP — would simply be gone, with the only copy sitting in a
/// plaintext file nothing reads any more.
///
/// The sync queue is the sharpest case. Its rows are, by definition, work the
/// server has never seen. Losing them is unrecoverable in a way losing a cached
/// catalog is not.
///
/// ## Design
///
/// Mirrors [LegacyRoutesImporter] deliberately, so the two read the same and a
/// reader who understands one understands the other:
///
/// - **Idempotent** — upserts keyed by the legacy primary key, plus a
///   completion marker in `app_metadata` that short-circuits re-runs.
/// - **One transaction** — the whole import lands or none of it does.
/// - **Never purges on its own** — [LegacyImportResult.safeToPurge] is advice;
///   deleting the plaintext source stays the caller's explicit decision.
///
/// It is simpler than the routes importer in one respect: these three tables
/// are self-contained, with no cross-database foreign key to reconcile, so
/// there are no orphan rows to skip. `skipped` is therefore always empty, and
/// `safeToPurge` reduces to "a real import ran and completed".
class LegacyOrdersImporter {
  LegacyOrdersImporter({
    required AppDatabase db,
    required LegacySqliteSource source,
    required AppLogger logger,
  })  : _db = db,
        _source = source,
        _logger = logger;

  final AppDatabase _db;
  final LegacySqliteSource _source;
  final AppLogger _logger;

  /// `app_metadata` key marking a completed import, so it runs at most once.
  static const String importedAtKey = 'migration.catalog_db.imported_at';

  Future<LegacyImportResult> import() async {
    if (await _db.appMetadataDao.getValue(importedAtKey) != null) {
      _logger.info('legacy_orders_import.skipped',
          fields: {'reason': 'already_done'});
      return const LegacyImportResult.alreadyImported();
    }
    if (!await _source.exists()) {
      // Fresh install — or any web build, where `AbsentLegacySource` always
      // reports false. Mark it done so a later reinstall-with-restore cannot
      // re-trigger an import of stale data.
      await _markDone();
      _logger.info('legacy_orders_import.skipped',
          fields: {'reason': 'no_source'});
      return const LegacyImportResult.noop(sourceMissing: true);
    }

    final imported = <String, int>{};

    try {
      await _db.transaction(() async {
        // Order matters only for readability here — there are no FKs between
        // these tables — but quotations are written first so that if a future
        // change does add the `sync_queue.quotation_id` FK, this order is
        // already correct.
        imported[_Legacy.quotations] = await _importRows(
          _Legacy.quotations,
          QuotationDao.columns,
          _db.quotationDao.upsert,
        );
        imported[_Legacy.salesOrders] = await _importRows(
          _Legacy.salesOrders,
          SalesOrderDao.columns,
          _db.salesOrderDao.upsert,
        );
        imported[_Legacy.syncQueue] = await _importRows(
          _Legacy.syncQueue,
          SyncQueueDao.columns,
          _db.syncQueueDao.upsert,
        );
        await _markDone();
      });
    } catch (error, stackTrace) {
      // The transaction rolled back — the encrypted database is untouched and
      // the plaintext source is intact, so a retry is safe. Surface it rather
      // than reporting a success the caller might act on by purging.
      _logger.error('legacy_orders_import.failed',
          error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      await _source.close();
    }

    // `SECURITY.md` §10: counts only. Never the rows — they carry depot
    // identifiers and revenue figures.
    _logger.info('legacy_orders_import.completed', fields: {
      'importedTotal': imported.values.fold<int>(0, (a, b) => a + b),
    });

    return LegacyImportResult(
      imported: imported,
      skipped: const {},
      alreadyDone: false,
      sourceMissing: false,
    );
  }

  /// Reads [table] and upserts every row through [write].
  ///
  /// Rows are projected onto [columns] rather than passed through verbatim. A
  /// legacy file may carry columns a later schema dropped, and an unexpected
  /// key would otherwise be bound positionally into the wrong slot. Missing
  /// keys land as null, which is what the legacy row already meant.
  Future<int> _importRows(
    String table,
    List<String> columns,
    Future<void> Function(DataMap row) write,
  ) async {
    final rows = await _source.readTable(table);
    for (final row in rows) {
      await write({for (final c in columns) c: row[c]});
    }
    return rows.length;
  }

  /// Empties the legacy business tables. Call **only** when
  /// [LegacyImportResult.safeToPurge] is true.
  ///
  /// Like T1.5, this empties tables rather than deleting the file: `catalog.db`
  /// also holds the product/category cache, which is harmless re-syncable data
  /// and not worth a separate deletion path. Removing the file itself is a
  /// follow-up once both legacy imports are confirmed across the fleet.
  Future<void> purgeLegacyData() async {
    for (final table in _Legacy.allDataTables) {
      await _source.deleteAllRows(table);
    }
    await _source.close();
  }

  Future<void> _markDone() => _db.appMetadataDao
      .setValue(importedAtKey, DateTime.now().toUtc().toIso8601String());
}
