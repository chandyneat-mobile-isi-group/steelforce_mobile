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

  /// Foreign keys are checked at commit, not per statement: the catalog's
  /// price and stock rows reference `products`. Discover the dependencies
  /// from SQLite itself and delete children before parents so adding a table
  /// or foreign key cannot silently reintroduce the sign-out failure.
  @override
  Future<void> clearForSignOut() => _db.transaction(() async {
        final tables = [
          for (final table in _db.allTables)
            if (!keptTables.contains(table.actualTableName))
              table.actualTableName,
        ];
        final order = await _childFirstOrder(tables);
        for (final name in order) {
          // Names come from Drift's compiled schema, not user input.
          await _db.customStatement('DELETE FROM "$name";');
        }

        final foreignKeyViolations =
            await _db.customSelect('PRAGMA foreign_key_check;').get();
        if (foreignKeyViolations.isNotEmpty) {
          throw StateError('Foreign-key violations remain after local reset.');
        }
        final integrity =
            await _db.customSelect('PRAGMA integrity_check;').getSingle();
        if (integrity.data.values.single != 'ok') {
          throw StateError('SQLite integrity check failed after local reset.');
        }
        await _db.appMetadataDao.deleteValue(ownerKey);
      });

  /// Reads the live SQLite constraints because Drift's table declaration
  /// order is not a dependency order. The graph is parent → dependent child;
  /// visiting children first gives the required delete order.
  Future<List<String>> _childFirstOrder(List<String> tables) async {
    final included = tables.toSet();
    final children = {for (final table in tables) table: <String>{}};
    for (final child in tables) {
      final quoted = child.replaceAll("'", "''");
      final foreignKeys =
          await _db.customSelect("PRAGMA foreign_key_list('$quoted');").get();
      for (final key in foreignKeys) {
        final parent = key.data['table'];
        if (parent is String && included.contains(parent)) {
          children[parent]!.add(child);
        }
      }
    }

    final ordered = <String>[];
    final visited = <String>{};
    final visiting = <String>{};
    void visit(String table) {
      if (visited.contains(table) || !visiting.add(table)) return;
      for (final child in children[table]!) {
        visit(child);
      }
      visiting.remove(table);
      visited.add(table);
      ordered.add(table);
    }

    for (final table in tables) {
      visit(table);
    }
    return ordered;
  }
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
    if (owner != null && owner != userId) {
      // A failed wipe must never be followed by an authenticated session for
      // the incoming rep. The auth layer catches this and clears the newly
      // issued credentials before exposing protected screens.
      await _reset.clearAll(rethrowOnFailure: true);
    }
    await _db.appMetadataDao
        .setValue(LocalDatabaseSessionStore.ownerKey, userId);
  }
}
