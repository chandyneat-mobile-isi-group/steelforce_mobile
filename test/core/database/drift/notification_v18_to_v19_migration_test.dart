import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v18 → v19: the notification tables arrive.
///
/// Purely additive, so the thing worth proving is not that the new tables exist
/// — a `createTable` that failed would be loud — but that **nothing already on
/// the device is disturbed**. A rep upgrading mid-route is carrying captured
/// visits and a sync queue that have never reached SAP, and a migration that
/// throws leaves them on a database that will not open at all.
///
/// The v18 fixture is built from Drift's own current DDL with the three new
/// tables dropped and `user_version` rewound, rather than hand-written from
/// memory. That keeps it honest: every other column, type and default is exactly
/// what ships today, and the only difference from v19 is what this step adds.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_notification_v19');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  const newTables = [
    'notifications',
    'notification_action_queue',
    'notification_sync_meta',
  ];

  /// Builds a v18 database: today's schema minus v19's tables.
  Future<void> createV18Fixture() async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    // Forces the lazy database open, which runs `onCreate`.
    await setup.customStatement('SELECT 1;');
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    for (final table in newTables) {
      raw.execute('DROP TABLE IF EXISTS $table;');
    }
    raw.execute('PRAGMA user_version = 18;');
    raw.dispose();
  }

  test('creates the three notification tables', () async {
    await createV18Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    // Opening runs the upgrade.
    await db.customStatement('SELECT 1;');

    for (final table in newTables) {
      final found = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
        variables: [Variable<String>(table)],
      ).get();
      expect(found, hasLength(1), reason: '$table should exist after v19');
    }

    await db.close();
  });

  test('records the new schema version', () async {
    await createV18Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    final version =
        await db.appMetadataDao.getValue(SchemaMetadataKeys.schemaVersion);
    final from =
        await db.appMetadataDao.getValue(SchemaMetadataKeys.lastMigratedFrom);

    expect(version, '$kCurrentSchemaVersion');
    expect(from, '18');

    await db.close();
  });

  test('leaves existing rows untouched', () async {
    await createV18Fixture();

    // A captured visit note and a queued sync row — both things that exist only
    // on the device until they are pushed, and both unrecoverable if lost.
    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute(
      // The note column is `text` in SQL and `body` in Dart — see `VisitNotes`.
      "INSERT INTO visit_notes (id, stop_id, type, text, created_at, "
      "updated_at, deleted, sync_state, dirty) "
      "VALUES ('vn1', 's1', 'general', 'Shop closed', 1756100000, "
      "1756100000, 0, 'dirty', 1);",
    );
    raw.execute(
      "INSERT INTO sync_queue (id, quotation_id, status, attempt_count, "
      "created_at, updated_at) "
      "VALUES ('sq1', 'q1', 'queued', 0, '2026-08-25T08:00:00Z', "
      "'2026-08-25T08:00:00Z');",
    );
    raw.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    final notes = await db.customSelect('SELECT text FROM visit_notes;').get();
    final queue = await db.customSelect('SELECT id FROM sync_queue;').get();

    expect(notes.single.read<String>('text'), 'Shop closed');
    expect(queue.single.read<String>('id'), 'sq1');

    await db.close();
  });

  test('the new tables carry no foreign keys (ADR-011)', () async {
    await createV18Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    for (final table in newTables) {
      final keys =
          await db.customSelect("PRAGMA foreign_key_list('$table');").get();
      expect(keys, isEmpty, reason: '$table must be a flat mirror');
    }

    await db.close();
  });

  test('a fresh install lands on v19 without walking the steps', () async {
    // The `onCreate` path, which `createAll` covers — asserted separately
    // because a table added to `@DriftDatabase` but forgotten in
    // `_stepwiseMigrations` passes this test and fails the upgrade one, and the
    // reverse is also possible.
    final db = AppDatabase(NativeDatabase.memory());
    final found = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name LIKE 'notification%';",
        )
        .get();

    expect(found.map((r) => r.read<String>('name')), containsAll(newTables));
    await db.close();
  });

  test('v19 is part of the shipped schema history', () {
    // Relaxed from an exact pin to a floor when v20 was added. The exact pin
    // belongs with the newest migration — it is a "did you add the step?"
    // tripwire, and pinning it here as well only meant every future bump broke
    // a notification test that has nothing to say about the new schema. The
    // current pin lives in `geo_v19_to_v20_migration_test.dart`.
    expect(kCurrentSchemaVersion, greaterThanOrEqualTo(19));
  });
}
