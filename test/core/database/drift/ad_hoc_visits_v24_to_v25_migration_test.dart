import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v24 → v25: a stop can exist without a planned window, and can say who put
/// it on the day.
///
/// ## What this is really guarding
///
/// SQLite has no `DROP NOT NULL`, so relaxing `planned_arrival` and
/// `planned_departure` means **rebuilding `route_stops` and copying every row
/// across**. A rebuild that loses rows is the classic way to wipe a rep's day,
/// and it fails silently — the app opens, the schema is right, and the stops
/// are simply gone. So the assertions below are mostly about survival: the
/// stop is still there, with its sequence, its status, its planned window and,
/// critically, its **unpushed local execution state**.
///
/// The second half of the step is why the nullability matters at all: an ad hoc
/// visit has no planned window, so before v25 the row could not be stored and
/// the route-sync transaction aborted — taking down the whole day rather than
/// one stop.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_v25_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Builds a v24 database: the current schema, seeded through Drift's own API,
  /// then rewound to what v24 physically had — `route_stops` with a NOT NULL
  /// planned window and no `visit_source`, and no `ad_hoc_visit_queue` at all.
  ///
  /// Rewinding rather than hand-writing v24 DDL keeps the fixture from drifting
  /// from what shipped; the rows are ones a real device really would have held.
  Future<void> createV24Fixture() async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.into(setup.routes).insert(
          RoutesCompanion.insert(
            id: 'route-1',
            name: 'PP Central — Tuesday',
            repId: 'rep-1',
            repName: 'Sok Dara',
            territory: 'PP-CENTRAL',
            visitDate: DateTime.utc(2026, 9, 29),
            plannedStart: DateTime.utc(2026, 9, 29, 8),
            plannedEnd: DateTime.utc(2026, 9, 29, 17),
            status: 'planned',
          ),
        );
    // Two stops, and the second one deliberately carries unpushed work: it is
    // checked in, dirty, and not yet synced. If the rebuild drops or resets
    // that, a rep loses a visit they have already made.
    await setup.into(setup.routeStops).insert(
          RouteStopsCompanion.insert(
            id: 'stop-1',
            routeId: 'route-1',
            depotId: 'dep-1',
            sequence: 1,
            plannedArrival: Value(DateTime.utc(2026, 9, 29, 9)),
            plannedDeparture: Value(DateTime.utc(2026, 9, 29, 9, 30)),
            status: 'pending',
          ),
        );
    await setup.into(setup.routeStops).insert(
          RouteStopsCompanion.insert(
            id: 'stop-2',
            routeId: 'route-1',
            depotId: 'dep-2',
            sequence: 2,
            plannedArrival: Value(DateTime.utc(2026, 9, 29, 10)),
            plannedDeparture: Value(DateTime.utc(2026, 9, 29, 10, 30)),
            status: 'checkedIn',
            actualArrival: Value(DateTime.utc(2026, 9, 29, 10, 4)),
            dirty: const Value(true),
            syncState: const Value('pending'),
          ),
        );
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    // Rebuild `route_stops` as v24 had it: NOT NULL window, no visit_source.
    // Done by hand because this is precisely the shape the migration has to
    // undo, and generating it from the current table would not reproduce it.
    raw.execute('ALTER TABLE route_stops RENAME TO route_stops_v24_src;');
    raw.execute('''
      CREATE TABLE route_stops (
        id TEXT NOT NULL,
        updated_at INTEGER NULL,
        deleted INTEGER NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1)),
        sync_state TEXT NOT NULL DEFAULT 'synced',
        server_revision TEXT NULL,
        dirty INTEGER NOT NULL DEFAULT 0 CHECK (dirty IN (0, 1)),
        route_id TEXT NOT NULL,
        depot_id TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        planned_arrival INTEGER NOT NULL,
        planned_departure INTEGER NOT NULL,
        status TEXT NOT NULL,
        actual_arrival INTEGER NULL,
        actual_departure INTEGER NULL,
        PRIMARY KEY (id)
      );
    ''');
    raw.execute('''
      INSERT INTO route_stops (id, updated_at, deleted, sync_state,
        server_revision, dirty, route_id, depot_id, sequence, planned_arrival,
        planned_departure, status, actual_arrival, actual_departure)
      SELECT id, updated_at, deleted, sync_state, server_revision, dirty,
        route_id, depot_id, sequence, planned_arrival, planned_departure,
        status, actual_arrival, actual_departure
      FROM route_stops_v24_src;
    ''');
    raw.execute('DROP TABLE route_stops_v24_src;');
    // Recreated because dropping the table dropped them. A real v24 device has
    // both, and drift's rebuild preserves whatever it finds in `sqlite_master`
    // — so a fixture without them would quietly test a weaker claim than the
    // one that matters: that the indexes survive the copy.
    raw.execute(
        'CREATE INDEX idx_route_stops_route ON route_stops (route_id);');
    raw.execute(
        'CREATE INDEX idx_route_stops_depot ON route_stops (depot_id);');
    raw.execute('DROP TABLE IF EXISTS ad_hoc_visit_queue;');
    raw.execute('PRAGMA user_version = 24;');
    raw.dispose();
  }

  test('the upgrade runs and lands on the current version', () async {
    await createV24Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });

  // The schema-version pin moved to `ad_hoc_queue_sk_v25_to_v26_migration_test.dart`.

  test('no stop is lost by the table rebuild', () async {
    await createV24Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final stops = await db.select(db.routeStops).get();
    expect(stops.map((s) => s.id).toSet(), {'stop-1', 'stop-2'});
  });

  test('every column survives the rebuild with its value intact', () async {
    await createV24Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final stop = await (db.select(db.routeStops)
          ..where((t) => t.id.equals('stop-1')))
        .getSingle();

    expect(stop.routeId, 'route-1');
    expect(stop.depotId, 'dep-1');
    expect(stop.sequence, 1);
    expect(stop.status, 'pending');
    expect(stop.plannedArrival, DateTime.utc(2026, 9, 29, 9));
    expect(stop.plannedDeparture, DateTime.utc(2026, 9, 29, 9, 30));
  });

  test('unpushed local execution state survives the rebuild', () async {
    await createV24Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final stop = await (db.select(db.routeStops)
          ..where((t) => t.id.equals('stop-2')))
        .getSingle();

    // A check-in the rep made offline. Losing this to a schema upgrade would
    // be indistinguishable, from the rep's side, from the visit never
    // happening — and there is no way to get it back.
    expect(stop.status, 'checkedIn');
    expect(stop.actualArrival, DateTime.utc(2026, 9, 29, 10, 4));
    expect(stop.dirty, isTrue);
    expect(stop.syncState, 'pending');
  });

  test('every migrated stop reads as a Call Plan stop', () async {
    await createV24Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final stops = await db.select(db.routeStops).get();
    // The column default, and the correct reading: every stop that existed
    // before v25 was issued by the Call Plan, because nothing else could put
    // one there.
    expect(stops.map((s) => s.visitSource).toSet(), {'callPlan'});
  });

  test('a stop with no planned window can now be stored', () async {
    await createV24Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // The whole point of the rebuild. Before v25 this insert failed with a
    // NOT NULL constraint violation *inside the route-sync transaction*, which
    // took down the rep's entire day rather than this one stop.
    await db.into(db.routeStops).insert(
          RouteStopsCompanion.insert(
            id: 'stop-adhoc',
            routeId: 'route-1',
            depotId: 'dep-9',
            sequence: 1001,
            status: 'pending',
            visitSource: const Value('adHoc'),
          ),
        );

    final stop = await (db.select(db.routeStops)
          ..where((t) => t.id.equals('stop-adhoc')))
        .getSingle();
    expect(stop.plannedArrival, isNull);
    expect(stop.plannedDeparture, isNull);
    expect(stop.visitSource, 'adHoc');
    expect(stop.sequence, 1001);
  });

  test('the ad hoc outbox exists and holds a request', () async {
    await createV24Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db.into(db.adHocVisitQueue).insert(
          AdHocVisitQueueCompanion.insert(
            id: 'req-1',
            depotId: 'dep-9',
            depotName: 'Toul Kork Yard',
            createdAt: DateTime.utc(2026, 9, 29, 14, 32),
          ),
        );

    final rows = await db.select(db.adHocVisitQueue).get();
    expect(rows.single.id, 'req-1');
    // Nothing has been attempted yet, which is the state a request is in
    // between the tap and the first send — the window the persisted id exists
    // to survive.
    expect(rows.single.attempts, 0);
    expect(rows.single.lastErrorCode, isNull);
  });

  test('the migrated schema matches a fresh install exactly', () async {
    await createV24Fixture();
    final upgraded = AppDatabase(NativeDatabase(dbFile));
    final upgradedSql = await _schemaOf(upgraded);
    await upgraded.close();

    final freshFile = File(p.join(tempDir.path, 'fresh.db'));
    final fresh = AppDatabase(NativeDatabase(freshFile));
    final freshSql = await _schemaOf(fresh);
    await fresh.close();

    // A generic guard, not a restatement of the step: anything the migration
    // does differently from `createAll()` shows up here, including a rebuild
    // that reconstructed the table with the wrong types or lost an index.
    expect(upgradedSql, freshSql);
  });
}

/// Every table and index definition, normalised and ordered so two databases
/// built by different routes can be compared directly.
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
