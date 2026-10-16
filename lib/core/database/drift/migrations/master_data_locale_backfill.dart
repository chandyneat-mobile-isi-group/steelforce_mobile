import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Forces one full re-sync of SAP-controlled master data so existing installs
/// pick up the Khmer half of every record.
///
/// ## Why this is needed at all
///
/// Making the feed bilingual is not enough. A device that has already synced
/// holds English-only rows *and* a `last_synced_at` watermark, and both sync
/// repositories only take the initial path when that watermark is `null`:
///
/// ```dart
/// final since = await _local.getLastSyncedAt(entity);
/// if (since == null) return runInitialSync();   // ← never true again
/// ```
///
/// Every subsequent sync is therefore a *delta*, which by definition only
/// carries rows the backend says changed. Nothing tells it that 11,000
/// unchanged rows just grew a Khmer name. The rep updates the app, sees the UI
/// chrome switch to Khmer, and every product/depot/shop name stays Latin —
/// which reads as "localization is broken" when the localization is fine and
/// the *local cache* is stale.
///
/// Clearing the watermark is the established remedy in this codebase: schema
/// migration v9 does exactly the same thing (`DELETE FROM catalog_sync_meta`)
/// for the same reason, with the same comment. This is that fix generalised to
/// all three master-data domains and detached from a schema bump, because the
/// tables did not change this time — only their *contents* did.
///
/// ## Why a marker instead of a schema version
///
/// There is no schema change to hang a migration off. A one-shot marker in
/// `app_metadata` gives the same run-exactly-once guarantee without a
/// gratuitous version bump and the `build_runner` churn that comes with it.
///
/// ## Safety
///
/// This only resets **cursors**, never rows. All three domains are
/// SAP-controlled and overwritten wholesale on sync (see `depots_table.dart`
/// — "reps have no write path to these columns"), so the worst case is one
/// larger-than-usual sync on the next launch. No rep-captured data — visits,
/// photos, quotations, the sync queue — is touched, and nothing is deleted.
///
/// It is also safe when it runs *before* the first sync (a fresh install):
/// clearing an already-empty cursor table is a no-op, the marker is written,
/// and the initial sync proceeds normally.
class MasterDataLocaleBackfill {
  const MasterDataLocaleBackfill({
    required AppDatabase db,
    required AppLogger logger,
  })  : _db = db,
        _logger = logger;

  final AppDatabase _db;
  final AppLogger _logger;

  /// Bump the suffix to force another backfill if a future change widens
  /// master data again. The old marker stays in the table; only an exact match
  /// counts as "already done", so a new value re-arms the reset.
  static const String markerKey = 'backfill.master_data_locale.v1';

  /// Clears the master-data sync cursors once. Returns `true` if it ran,
  /// `false` if it had already been done on this install.
  Future<bool> run() async {
    final done = await _db.appMetadataDao.getValue(markerKey);
    if (done != null) return false;

    // One transaction: either every cursor is cleared and the marker written,
    // or nothing is. A partial reset would leave, say, depots re-syncing
    // while the catalog stayed stale — and because the marker would be missing
    // it would retry forever, re-running a full catalog sync on every launch.
    await _db.transaction(() async {
      await _db.delete(_db.catalogSyncMeta).go();
      await _db.delete(_db.depotSyncMeta).go();
      await _db.delete(_db.routeSyncMeta).go();
      await _db.appMetadataDao
          .setValue(markerKey, DateTime.now().toUtc().toIso8601String());
    });

    _logger.info('bootstrap.master_data_locale_backfill');
    return true;
  }
}
