import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v27 → v28: a check-in records its route; a check-out records how the visit
/// ended (`check-in-check-out-mobile.md` §11).
///
/// Purely additive and nullable. What matters is that a check-in and a
/// check-out already queued under v27 survive with every value intact — they
/// are a rep's unsent fieldwork — and simply have no outcome, which the server
/// stores as `unknown`.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_v28_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// The current schema without the v28 columns, holding one queued check-in
  /// and check-out, rewound to v27.
  Future<void> createV27Fixture() async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.customSelect('SELECT 1;').get();
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('ALTER TABLE visit_check_ins DROP COLUMN route_id;');
    for (final column in [
      'check_in_id',
      'outcome',
      'orders_json',
      'no_order_reason',
      'no_order_note',
    ]) {
      raw.execute('ALTER TABLE visit_check_outs DROP COLUMN $column;');
    }
    raw.execute(
      "INSERT INTO visit_check_ins (id, stop_id, timestamp, latitude, "
      "longitude, accuracy, distance_from_depot) "
      "VALUES ('ci-v27', 'stop-1', '2026-10-05T02:00:00.000Z', 11.55, 104.91, 8, 20);",
    );
    raw.execute(
      "INSERT INTO visit_check_outs (id, stop_id, timestamp, latitude, "
      "longitude, duration_minutes, visit_summary) "
      "VALUES ('co-v27', 'stop-1', '2026-10-05T02:40:00.000Z', 11.55, 104.91, 40, "
      "'Visit completed');",
    );
    raw.execute('PRAGMA user_version = 27;');
    raw.dispose();
  }

  /// The schema-version pin, handed on from
  /// `depot_registration_queue_v26_to_v27_migration_test.dart`. It lives with
  /// the newest migration test; move it — and add the step — together with
  /// the next schema change.
  test('the schema version is pinned to this migration', () {
    expect(kCurrentSchemaVersion, 28);
  });

  test('the upgrade runs and lands on the current version', () async {
    await createV27Fixture();
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });

  test('queued check-ins and check-outs survive, with no outcome', () async {
    await createV27Fixture();
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final checkIn = (await db.select(db.visitCheckIns).get()).single;
    expect(checkIn.id, 'ci-v27');
    expect(checkIn.distanceFromDepot, 20);
    expect(checkIn.syncState, 'dirty');
    expect(checkIn.routeId, isNull);

    final checkOut = (await db.select(db.visitCheckOuts).get()).single;
    expect(checkOut.id, 'co-v27');
    expect(checkOut.durationMinutes, 40);
    expect(checkOut.syncState, 'dirty');
    expect(checkOut.outcome, isNull);
    expect(checkOut.checkInId, isNull);
    expect(checkOut.ordersJson, isNull);
  });

  test('the new columns take a check-out with an outcome', () async {
    await createV27Fixture();
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db.visitDao.upsertCheckOut(VisitCheckOutsCompanion.insert(
      id: 'co-v28',
      stopId: 'stop-2',
      timestamp: DateTime.utc(2026, 10, 5, 3),
      latitude: 11.55,
      longitude: 104.91,
      durationMinutes: 20,
      visitSummary: 'Visit completed',
      checkInId: const Value('ci-2'),
      outcome: const Value('withoutOrder'),
      noOrderReason: const Value('other'),
      noOrderNote: const Value('Owner travelling'),
    ));

    final row = await (db.select(db.visitCheckOuts)
          ..where((t) => t.id.equals('co-v28')))
        .getSingle();
    expect(row.outcome, 'withoutOrder');
    expect(row.noOrderNote, 'Owner travelling');
  });

  test('the migrated schema matches a fresh install exactly', () async {
    await createV27Fixture();
    final upgraded = AppDatabase(NativeDatabase(dbFile));
    final upgradedSql = await _schemaOf(upgraded);
    await upgraded.close();

    final fresh =
        AppDatabase(NativeDatabase(File(p.join(tempDir.path, 'fresh.db'))));
    final freshSql = await _schemaOf(fresh);
    await fresh.close();

    expect(upgradedSql, freshSql);
  });
}

Future<List<String>> _schemaOf(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT sql FROM sqlite_master "
        "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY name;",
      )
      .get();
  return rows
      .map((r) => r.read<String>('sql').replaceAll(RegExp(r'\s+'), ' ').trim())
      .toList()
    ..sort();
}
