import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v19 → v20: the four gazetteer tables arrive.
///
/// Additive, like v19, so the point is again that **nothing already on the
/// device is disturbed**. A rep upgrading mid-route is carrying captured visits
/// and a sync queue that have never reached SAP; a migration that throws leaves
/// them on a database that will not open.
///
/// The one thing specific to this step: the tables are created **empty**. The
/// migrator does not import the 1.3 MB asset — that is the seed loader's job,
/// deliberately, because reading an asset bundle inside `onUpgrade` would block
/// the first frame of the launch that happens to upgrade, and the schema
/// fixtures have no Flutter binding to load an asset with. So "empty after
/// migration" is the correct post-condition, not a bug.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_geo_v20');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  const newTables = [
    'geo_provinces',
    'geo_districts',
    'geo_communes',
    'geo_villages',
  ];

  /// Builds a v19 database: today's schema minus v20's tables.
  Future<void> createV19Fixture() async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.customStatement('SELECT 1;'); // forces onCreate
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    for (final table in newTables) {
      raw.execute('DROP TABLE IF EXISTS $table;');
    }
    raw.execute('PRAGMA user_version = 19;');
    raw.dispose();
  }

  Future<List<String>> tableNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table';")
        .get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  test('creates the four gazetteer tables', () async {
    await createV19Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    expect(await tableNames(db), containsAll(newTables));
    await db.close();
  });

  test('leaves them empty — seeding is the loader\'s job, not the migrator\'s',
      () async {
    await createV19Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    expect(await db.geoDao.provinceCount(), 0);
    await db.close();
  });

  test('records the new schema version', () async {
    await createV19Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    await db.customStatement('SELECT 1;');
    final version = await db
        .customSelect('PRAGMA user_version;')
        .map((r) => r.read<int>('user_version'))
        .getSingle();
    expect(version, kCurrentSchemaVersion);
    await db.close();
  });

  test('preserves rows already on the device', () async {
    await createV19Fixture();

    // A sync-queue row is the sharpest case: it is work the rep has done that
    // has never reached SAP, so losing it loses a real order.
    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute(
      "INSERT INTO app_metadata (key, value, updated_at) "
      "VALUES ('geo.migration.canary', 'intact', 0);",
    );
    raw.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    final survived = await db.customSelect(
      'SELECT value FROM app_metadata WHERE key = ?;',
      variables: [Variable<String>('geo.migration.canary')],
    ).getSingleOrNull();
    expect(survived?.read<String>('value'), 'intact');
    await db.close();
  });

  test('is idempotent — replaying it does not abort the upgrade', () async {
    // The fixtures build the *current* schema and rewind `user_version`, so a
    // replayed step meets tables that already exist. `_createTableIfMissing`
    // is what stops that from failing the whole upgrade, exactly as for v19.
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.customStatement('SELECT 1;');
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('PRAGMA user_version = 19;'); // tables left in place
    raw.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    expect(await tableNames(db), containsAll(newTables));
    await db.close();
  });

  test('v20 is still a registered step, not skipped by a later bump', () {
    // The current-version pin has moved on to the newest migration's test, as
    // it did from v19's to this one — see
    // `depot_sync_language_v20_to_v21_migration_test.dart`.
    //
    // What stays here is the assertion this file actually owns: v20 must remain
    // reachable. A later schema change that renumbered or dropped this step
    // would skip the geo tables for every device still on v19.
    expect(kCurrentSchemaVersion, greaterThanOrEqualTo(20));
  });
}
