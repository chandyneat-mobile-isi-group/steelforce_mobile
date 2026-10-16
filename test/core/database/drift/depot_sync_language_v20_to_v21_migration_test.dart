import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v20 → v21: `depot_sync_meta.synced_language`.
///
/// The column records which `Accept-Language` the cached depot book was
/// fetched under. `shopName` is localised **server-side** and the list summary
/// carries no language-independent name, so a book pulled under `km-KH` holds
/// Khmer names — and a delta cannot repair that, because `modifiedSince`
/// returns what the *server* changed and switching language on the phone
/// changes nothing there.
///
/// Additive and nullable, so the migration must preserve the existing watermark
/// untouched: an upgrade that lost it would trigger a needless full re-page of
/// every depot on every installed device.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_v21_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Builds a v20 database from the current schema by dropping exactly what v21
  /// adds, then rewinding `user_version`. The base tables are Drift's own DDL,
  /// so the fixture cannot drift from what ships.
  Future<void> createV20Fixture({String? watermark}) async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.customStatement('SELECT 1;');
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('DROP TABLE depot_sync_meta;');
    raw.execute('CREATE TABLE depot_sync_meta ('
        'entity TEXT NOT NULL, last_synced_at TEXT NULL, '
        'PRIMARY KEY (entity));');
    if (watermark != null) {
      raw.execute(
        "INSERT INTO depot_sync_meta (entity, last_synced_at) "
        "VALUES ('depots', ?)",
        [watermark],
      );
    }
    raw.execute('PRAGMA user_version = 20;');
    raw.dispose();
  }

  test('the upgrade runs and lands on the current version', () async {
    await createV20Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // Opening a v20 file replays every step up to whatever ships today, not
    // just this one. Asserting a literal `21` here made a correct later schema
    // bump look like a broken migration.
    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });

  test('an existing watermark survives, with the language left unknown',
      () async {
    await createV20Fixture(watermark: '2026-08-28T08:31:52.000Z');

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT last_synced_at, synced_language "
            "FROM depot_sync_meta WHERE entity = 'depots'")
        .getSingle();

    expect(row.data['last_synced_at'], '2026-08-28T08:31:52.000Z',
        reason: 'losing the watermark would force every installed device '
            'through a full re-page of every depot');
    expect(row.data['synced_language'], isNull,
        reason: 'null reads as "unknown", which the sync repository treats as '
            'a match rather than forcing a gratuitous resync on upgrade');
  });

  test('the upgraded table accepts a language', () async {
    await createV20Fixture(watermark: '2026-08-28T08:31:52.000Z');

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db.depotDao.setLastSyncedAt(
      'depots',
      DateTime.utc(2026, 8, 28, 9),
      language: 'km-KH',
    );

    expect(await db.depotDao.getSyncedLanguage('depots'), 'km-KH');
  });

  test('a fresh install lands on v21 with the column present', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.depotDao.setLastSyncedAt(
      'depots',
      DateTime.utc(2026, 8, 28),
      language: 'en-US',
    );

    expect(await db.depotDao.getSyncedLanguage('depots'), 'en-US');
  });

  test('v21 still upgrades from v20 after later schema changes', () {
    // The version pin has moved on to
    // `check_in_override_reason_v21_to_v22_migration_test.dart`, as this
    // test's own instruction said it should when the next schema change
    // landed. What stays here is the part that keeps mattering: v20 databases
    // are still in the field, and this file is what proves they can still get
    // here.
    expect(kCurrentSchemaVersion, greaterThanOrEqualTo(21));
  });
}
