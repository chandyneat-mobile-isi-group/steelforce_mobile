import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v17 → v18: the ADR-011 upgrade must remove constraints **without losing a
/// single row**.
///
/// This is the test that matters most in this change. A migration that throws
/// leaves a real rep on a database that will not open, and one that silently
/// drops rows destroys captured field work that was never pushed — the precise
/// harm ADR-011 was adopted to prevent. Asserting the constraints are gone is
/// not enough; the data has to come across too.
///
/// The v17 fixture is built from Drift's own current DDL with the foreign keys
/// re-injected, rather than hand-written from memory. That keeps the fixture
/// honest: every column, type and default is exactly what ships today, and the
/// only difference from v18 is the thing this migration changes.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_adr011_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// The foreign keys v17 had and v18 removes.
  const v17ForeignKeys = <String, List<String>>{
    'route_stops': [
      'FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE',
      'FOREIGN KEY (depot_id) REFERENCES depots (id)',
    ],
    'visit_check_ins': [
      'FOREIGN KEY (stop_id) REFERENCES route_stops (id) ON DELETE CASCADE',
    ],
    'visit_notes': [
      'FOREIGN KEY (stop_id) REFERENCES route_stops (id) ON DELETE CASCADE',
    ],
    'depot_notes': [
      'FOREIGN KEY (depot_id) REFERENCES depots (id)',
    ],
  };

  Future<void> createV17Fixture() async {
    // Start from the real, current schema so the fixture cannot drift.
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.customStatement('SELECT 1;');
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);

    // v18 introduced route_depots; v17 had no such table.
    raw.execute('DROP TABLE IF EXISTS route_depots;');

    // Rebuild each affected table with its v17 constraints restored.
    for (final entry in v17ForeignKeys.entries) {
      final ddl = raw.select(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
        [entry.key],
      ).first['sql'] as String;

      final cut = ddl.lastIndexOf(')');
      final withFks =
          '${ddl.substring(0, cut)}, ${entry.value.join(', ')}${ddl.substring(cut)}';

      raw.execute('DROP TABLE ${entry.key};');
      raw.execute(withFks);
    }

    // A rep's day, mid-visit: a depot, a route, a stop, and two captures
    // that have not been pushed yet.
    raw.execute(
      "INSERT INTO depots (id, depot_code, shop_name, owner_name, phone, "
      "address, province, district, territory, latitude, longitude, "
      "credit_limit, status, assigned_rep_id, assigned_rep_name, updated_at, "
      "kh_name, territory_type, geofence_radius_override) "
      "VALUES ('cust-1','C-1','Toul Kork Depot','Heng Vuthy','023456005',"
      "'St 271','PP','TK','PP-NORTH',11.5788,104.8901,30000,'Active','rep-1',"
      "'Rep One',0,'ឃ្លាំង','industrial',150)",
    );
    raw.execute(
      "INSERT INTO routes (id, name, rep_id, rep_name, territory, visit_date, "
      "planned_start, planned_end, status) "
      "VALUES ('r-1','North loop','rep-1','Rep One','PP-NORTH',0,0,0,'published')",
    );
    raw.execute(
      "INSERT INTO route_stops (id, route_id, depot_id, sequence, "
      "planned_arrival, planned_departure, status) "
      "VALUES ('s-1','r-1','cust-1',1,0,0,'checkedIn')",
    );
    raw.execute(
      "INSERT INTO visit_check_ins (id, stop_id, timestamp, latitude, "
      "longitude, accuracy, distance_from_depot, is_mocked) "
      "VALUES ('ci-1','s-1',0,11.5788,104.8901,5.0,12.0,0)",
    );
    raw.execute(
      "INSERT INTO visit_notes (id, stop_id, type, text, created_at) "
      "VALUES ('n-1','s-1','general','Wants a rebar quote Thursday',0)",
    );
    raw.execute(
      "INSERT INTO depot_notes (id, depot_id, body, created_at) "
      "VALUES ('cn-1','cust-1','Pays on time',0)",
    );

    raw.execute('PRAGMA user_version = 17;');
    raw.dispose();
  }

  test('the upgrade runs and every row survives it', () async {
    await createV17Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // Opening triggers onUpgrade. If this throws, a real device is bricked.
    //
    // Asserted against [kCurrentSchemaVersion] rather than the literal 18: the
    // walk continues through every later step, so pinning the number here made
    // this test fail on the next schema bump for a reason that has nothing to do
    // with ADR-011. What this test is actually about is the rows below.
    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);

    Future<int> count(String table) async =>
        (await db.customSelect('SELECT COUNT(*) c FROM $table').getSingle())
            .data['c']! as int;

    expect(await count('depots'), 1);
    expect(await count('routes'), 1);
    expect(await count('route_stops'), 1);
    expect(await count('depot_notes'), 1);

    // The two that a careless table rebuild would have silently dropped.
    expect(await count('visit_check_ins'), 1,
        reason: 'an unpushed check-in was lost by the migration');
    expect(await count('visit_notes'), 1,
        reason: 'an unpushed note was lost by the migration');

    // Content, not just cardinality — a rebuild can preserve a row's existence
    // while mangling its columns.
    final note = await db
        .customSelect("SELECT text FROM visit_notes WHERE id='n-1'")
        .getSingle();
    expect(note.data['text'], 'Wants a rebar quote Thursday');

    final stop = await db
        .customSelect("SELECT status, depot_id FROM route_stops WHERE id='s-1'")
        .getSingle();
    expect(stop.data['status'], 'checkedIn');
    expect(stop.data['depot_id'], 'cust-1');
  });

  test('existing stops are backfilled so nothing renders blank', () async {
    await createV17Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // Without this backfill an upgrading rep would open the app to a day of
    // stop cards showing a bare depot id, because route_depots starts
    // empty and the next route sync may be hours away.
    final row = await db
        .customSelect("SELECT * FROM route_depots WHERE id='cust-1'")
        .getSingle();

    expect(row.data['name'], 'Toul Kork Depot');
    expect(row.data['name_kh'], 'ឃ្លាំង');
    expect(row.data['code'], 'C-1');
    expect(row.data['contact'], 'Heng Vuthy');
    expect(row.data['territory_type'], 'industrial');
    expect(row.data['geofence_radius_override'], 150);
  });

  test('a depot with no territory type backfills fail-closed', () async {
    await createV17Fixture();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute("UPDATE depots SET territory_type = NULL");
    raw.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final row = await db
        .customSelect(
            "SELECT territory_type FROM route_depots WHERE id='cust-1'")
        .getSingle();

    // 'urban' is the tightest geofence (50 m), matching kUnknownTerritoryFallback:
    // an unknown territory must block a doubtful check-in, never wave it through.
    expect(row.data['territory_type'], 'urban');
  });

  test('the constraints really are gone after the upgrade', () async {
    await createV17Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final rows = await db
        .customSelect("SELECT name, sql FROM sqlite_master WHERE type='table'")
        .get();
    final sql = {
      for (final r in rows)
        r.data['name'] as String: (r.data['sql'] as String?) ?? '',
    };

    expect(sql['route_stops'], isNot(contains('FOREIGN KEY')));
    expect(sql['visit_check_ins'], isNot(contains('FOREIGN KEY')));
    expect(sql['visit_notes'], isNot(contains('FOREIGN KEY')));
    expect(sql['depot_notes'], isNot(contains('FOREIGN KEY')));

    // And the upgraded database accepts the write that v17 refused.
    await db.customStatement(
      "INSERT INTO route_stops (id, route_id, depot_id, sequence, "
      "planned_arrival, planned_departure, status) "
      "VALUES ('s-2','r-1','not-synced-yet',2,0,0,'pending')",
    );
    final stops =
        await db.customSelect('SELECT COUNT(*) c FROM route_stops').getSingle();
    expect(stops.data['c'], 2);
  });
}
