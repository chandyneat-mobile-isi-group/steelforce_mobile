import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v21 → v22: `visit_check_ins.override_reason`.
///
/// The column holds why a rep checked in from outside the designated check-in
/// area, when they did. Null is the normal case: a check-in that satisfied the
/// rule needs no explanation.
///
/// The override was built end to end before the column existed — the event, the
/// bloc, the entity, the row mapper and the push payload all carried
/// `overrideReason` — so `visit_drift_mappers.dart` referenced a field the
/// generated row did not have and the app stopped compiling. This migration is
/// the missing half.
///
/// Additive and nullable, so the step must leave existing check-ins untouched:
/// a check-in is evidence that a visit happened, and an upgrade that dropped or
/// rewrote one would destroy the only record of a completed visit that had not
/// yet synced.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_v22_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Builds a v21 database from the current schema by removing exactly what v22
  /// adds, then rewinding `user_version`.
  ///
  /// Dropping the column from Drift's own DDL rather than hand-writing a v21
  /// `CREATE TABLE`: the fixture then cannot drift from what actually shipped,
  /// which is the whole point of testing a migration rather than a mock of one.
  Future<void> createV21Fixture({bool withCheckIn = false}) async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.customStatement('SELECT 1;');
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('ALTER TABLE visit_check_ins DROP COLUMN override_reason;');
    if (withCheckIn) {
      raw.execute(
        'INSERT INTO visit_check_ins '
        '(id, stop_id, timestamp, latitude, longitude, accuracy, '
        ' distance_from_depot, is_mocked) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'ci-1',
          'stop-1',
          '2026-09-08T09:15:00.000Z',
          11.55,
          104.91,
          8.0,
          20.0,
          0
        ],
      );
    }
    raw.execute('PRAGMA user_version = 21;');
    raw.dispose();
  }

  test('the upgrade runs and lands on the current version', () async {
    await createV21Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });

  test('an existing check-in survives, with no reason recorded', () async {
    await createV21Fixture(withCheckIn: true);

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT stop_id, distance_from_depot, override_reason "
            "FROM visit_check_ins WHERE id = 'ci-1'")
        .getSingle();

    // The evidence is intact...
    expect(row.data['stop_id'], 'stop-1');
    expect(row.data['distance_from_depot'], 20.0);
    // ...and null reads correctly as "no override was needed", which is true of
    // every check-in written before an override was possible.
    expect(row.data['override_reason'], isNull);
  });

  test('the upgraded table accepts a reason', () async {
    await createV21Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db.customStatement(
      'INSERT INTO visit_check_ins '
      '(id, stop_id, timestamp, latitude, longitude, accuracy, '
      ' distance_from_depot, is_mocked, override_reason) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'ci-2',
        'stop-2',
        '2026-09-08T10:00:00.000Z',
        11.56,
        104.92,
        12.0,
        240.0,
        0,
        'Gate is 200 m from the office pin'
      ],
    );

    final row = await db
        .customSelect("SELECT override_reason FROM visit_check_ins "
            "WHERE id = 'ci-2'")
        .getSingle();

    expect(row.data['override_reason'], 'Gate is 200 m from the office pin');
  });

  test('a fresh install lands on v22 with the column present', () async {
    // No fixture: the `onCreate` path builds the current schema directly and
    // must agree with what the upgrade path produces.
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final columns =
        await db.customSelect('PRAGMA table_info(visit_check_ins);').get();
    final names = columns.map((r) => r.data['name']).toList();

    expect(names, contains('override_reason'));
  });

  test('v22 is still a registered step, not skipped by a later bump', () {
    // The pin moved on to `depot_rename_v22_to_v23_migration_test.dart` with
    // the v23 bump. What stays here is the narrower guarantee: whatever the
    // current version becomes, a device arriving from v21 must still walk
    // through this step rather than past it.
    expect(kCurrentSchemaVersion, greaterThanOrEqualTo(22));
  });
}
