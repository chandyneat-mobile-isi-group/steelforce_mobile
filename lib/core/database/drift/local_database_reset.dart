import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';

/// Empties the encrypted database on sign-out, so nothing one rep saw or
/// saved is on the device when the next session starts. Every screen then
/// reads from the API again after sign-in, and only falls back to what it
/// writes locally from then on.
///
/// Wipes by exclusion: a table added later is cleared without anyone having
/// to remember this file. What is kept is not rep data:
///
///  * the Cambodian gazetteer — bundled with the app, imported once from an
///    asset, and with no endpoint to restore it from (`geo_tables.dart`);
///  * `app_metadata` — schema and one-time-import bookkeeping. Clearing it
///    would make the legacy importers run again on the next start.
///
/// Callers must not reach this while work is unsent: [UnsentWorkService]
/// gates the sign-out that runs it.
class LocalDatabaseSessionStore implements SessionScopedStore {
  const LocalDatabaseSessionStore(this._db);

  final AppDatabase _db;

  static const keptTables = <String>{
    'app_metadata',
    'geo_provinces',
    'geo_districts',
    'geo_communes',
    'geo_villages',
  };

  /// The rep whose data the database currently holds. See
  /// [LocalDataOwnership].
  static const ownerKey = 'session.owner_user_id';

  @override
  String get debugName => 'local database';

  @override
  Future<void> clearForSignOut() => _db.transaction(() async {
        for (final table in _db.allTables) {
          if (keptTables.contains(table.actualTableName)) continue;
          await _db.delete(table).go();
        }
        await _db.appMetadataDao.deleteValue(ownerKey);
      });
}

/// Records which rep the local data belongs to, and wipes it before a
/// *different* rep signs in.
///
/// A rep-initiated sign-out already wipes everything. This covers the path
/// that does not: a session that expired on its own leaves the data in place,
/// which is right when the same rep signs back in (their unsent visits still
/// go out) and wrong when someone else does — they would see the previous
/// rep's depots and visits, and push that rep's captures under their own
/// token.
class LocalDataOwnership {
  const LocalDataOwnership(this._db, this._reset);

  final AppDatabase _db;
  final SessionResetService _reset;

  Future<void> claim(String userId) async {
    final owner =
        await _db.appMetadataDao.getValue(LocalDatabaseSessionStore.ownerKey);
    if (owner != null && owner != userId) await _reset.clearAll();
    await _db.appMetadataDao
        .setValue(LocalDatabaseSessionStore.ownerKey, userId);
  }
}
