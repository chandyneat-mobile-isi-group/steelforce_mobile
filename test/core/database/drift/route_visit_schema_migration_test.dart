import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Covers the T1.5 schema landing (v7/v8): the route + visit-capture tables
/// ported off the plaintext `routes.db` into the single encrypted database
/// (ADR-001).
///
/// `docs/blueprint/local-storage-architecture.md` §5 requires every migration step to ship with a test
/// that runs the upgrade against a fixture of the *previous* schema version and
/// asserts data survives intact — migrations are proven before merge, not
/// discovered broken in the field. That is the `v6 → v8 upgrade` group below.
///
/// Runs on an in-memory/temp-file `NativeDatabase` (no SQLCipher) so it works on
/// host CI; the cipher wrapper is covered on-device separately.
void main() {
  group('v8 schema — route + visit tables exist after onCreate', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('schema version matches the registry constant', () async {
      // Asserted against the constant rather than a literal so a version bump
      // (v9 added the SAP sales-area columns) doesn't fail a test that is
      // really about the route/visit tables.
      expect(db.schemaVersion, kCurrentSchemaVersion);
    });

    test('every ported table is created', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table';")
          .get();
      final tables = rows.map((r) => r.data['name'] as String).toSet();

      expect(
        tables,
        containsAll([
          // v7 — route domain
          'routes', 'route_stops', 'location_samples', 'fraud_flags',
          'route_sync_meta',
          // v8 — visit captures
          'visit_check_ins', 'visit_check_outs', 'visit_order_lines',
          'visit_stock_updates', 'visit_returns', 'visit_collections',
          'visit_notes', 'visit_photos',
        ]),
      );
    });

    test('depots absorbs the two route-execution columns', () async {
      final rows = await db.customSelect('PRAGMA table_info(depots);').get();
      final columns = rows.map((r) => r.data['name'] as String).toSet();

      expect(
          columns, containsAll(['territory_type', 'geofence_radius_override']));
    });
  });

  group('referential integrity — what the schema does and does not enforce',
      () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> insertRoute(String id) => db.into(db.routes).insert(
          RoutesCompanion.insert(
            id: id,
            name: 'R1',
            repId: 'rep-1',
            repName: 'Rep',
            territory: 'T1',
            visitDate: DateTime.utc(2026, 7, 15),
            plannedStart: DateTime.utc(2026, 7, 15, 8),
            plannedEnd: DateTime.utc(2026, 7, 15, 17),
            status: 'planned',
          ),
        );

    // ── ADR-011 reversed both of these ───────────────────────────────
    //
    // They used to assert that a stop referencing an unknown depot or an
    // unknown route was rejected, as "the win ADR-001 was adopted for". In
    // practice the rejection aborted the entire route-write transaction, so
    // one unrecognised depot cost the rep every stop of their day rather
    // than the one bad row. The backend validates these relationships before
    // it sends the payload; the device's job is to store what arrived.

    test('a stop whose depot has not synced yet is stored, not rejected',
        () async {
      await insertRoute('route-1');

      await db.into(db.routeStops).insert(
            RouteStopsCompanion.insert(
              id: 'stop-1',
              routeId: 'route-1',
              depotId: 'ghost-depot',
              sequence: 1,
              plannedArrival: Value(DateTime.utc(2026, 7, 15, 9)),
              plannedDeparture: Value(DateTime.utc(2026, 7, 15, 10)),
              status: 'pending',
            ),
          );

      final stored = await db.select(db.routeStops).get();
      expect(stored, hasLength(1));
      expect(stored.single.depotId, 'ghost-depot');
    });

    test('a stop whose route has not been written yet is stored too', () async {
      await db.into(db.routeStops).insert(
            RouteStopsCompanion.insert(
              id: 'stop-1',
              routeId: 'ghost-route',
              depotId: 'ghost-depot',
              sequence: 1,
              plannedArrival: Value(DateTime.utc(2026, 7, 15, 9)),
              plannedDeparture: Value(DateTime.utc(2026, 7, 15, 10)),
              status: 'pending',
            ),
          );

      expect(await db.select(db.routeStops).get(), hasLength(1));
    });

    test('deleting a route cascades to its GPS trail', () async {
      await insertRoute('route-1');
      await db.into(db.locationSamples).insert(
            LocationSamplesCompanion.insert(
              id: 'sample-1',
              routeId: 'route-1',
              latitude: 11.55,
              longitude: 104.91,
              accuracy: 5,
              speed: 0,
              heading: 0,
              altitude: 12,
              timestamp: DateTime.utc(2026, 7, 15, 9),
            ),
          );

      await (db.delete(db.routes)..where((t) => t.id.equals('route-1'))).go();

      expect(await db.select(db.locationSamples).get(), isEmpty);
    });
  });

  group('syncable columns (DATABASE_GUIDE §3.1)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a locally-created row defaults to dirty and not-yet-synced',
        () async {
      await db.into(db.routes).insert(
            RoutesCompanion.insert(
              id: 'route-1',
              name: 'R1',
              repId: 'rep-1',
              repName: 'Rep',
              territory: 'T1',
              visitDate: DateTime.utc(2026, 7, 15),
              plannedStart: DateTime.utc(2026, 7, 15, 8),
              plannedEnd: DateTime.utc(2026, 7, 15, 17),
              status: 'planned',
            ),
          );

      final row = await db.select(db.routes).getSingle();

      // A row written locally has by definition not reached SAP yet.
      expect(row.syncState, SyncStates.dirty);
      expect(row.dirty, isTrue);
      expect(row.deleted, isFalse);
      expect(row.serverRevision, isNull);
      expect(row.updatedAt, isNotNull);
    });

    test('the schema default literal still matches SyncStates.dirty', () {
      // Guards the deliberate literal in SyncableTable.syncState: Drift copies
      // that expression into app_database.g.dart, which cannot import
      // SyncStates. If someone renames the constant, this fails instead of the
      // schema silently defaulting to a stale value.
      expect(SyncStates.dirty, 'dirty');
    });
  });

  group('legacy sync_status mapping (T1.5 import)', () {
    test("'pending' maps to dirty", () {
      expect(SyncStates.fromLegacy('pending'), SyncStates.dirty);
    });

    test('null maps to dirty rather than assuming synced', () {
      expect(SyncStates.fromLegacy(null), SyncStates.dirty);
    });

    test('an unknown value maps to dirty — re-push is safe, data loss is not',
        () {
      expect(SyncStates.fromLegacy('weird'), SyncStates.dirty);
    });

    test('known canonical values round-trip', () {
      expect(SyncStates.fromLegacy('synced'), SyncStates.synced);
      expect(SyncStates.fromLegacy('syncing'), SyncStates.syncing);
      expect(SyncStates.fromLegacy('conflict'), SyncStates.conflict);
    });
  });

  group('v6 → v8 upgrade preserves data (DATABASE_GUIDE §5)', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('isi_migration_test');
      dbFile = File(p.join(tempDir.path, 'app.db'));
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    /// Fabricates a v6 database on disk.
    ///
    /// No historical v6 snapshot exists (schema dumps were never captured), so
    /// v6 is reconstructed from the current schema by removing exactly what v7
    /// and v8 add, then rewinding `user_version`. This keeps the fixture honest
    /// — the base tables are Drift's own DDL, not a hand-written approximation
    /// that could drift from reality.
    Future<void> createV6Fixture() async {
      final setup = AppDatabase(NativeDatabase(dbFile));
      await setup.customStatement('SELECT 1;'); // force open → onCreate (v8)
      await setup.close();

      final raw = sqlite.sqlite3.open(dbFile.path);
      for (final table in [
        'visit_photos',
        'visit_notes',
        'visit_collections',
        'visit_returns',
        'visit_stock_updates',
        'visit_order_lines',
        'visit_check_outs',
        'visit_check_ins',
        'fraud_flags',
        'location_samples',
        'route_stops',
        'route_sync_meta',
        'routes',
      ]) {
        raw.execute('DROP TABLE IF EXISTS $table;');
      }
      // Indexes first — SQLite refuses to drop a column an index references.
      raw.execute('DROP INDEX IF EXISTS idx_depots_sales_org;');
      raw.execute('DROP INDEX IF EXISTS idx_depots_division;');
      // v9's SAP columns must come off too, otherwise step 9 re-adds columns
      // that already exist and the upgrade fails with "duplicate column name".
      for (final column in [
        'sales_org',
        'division',
        'distribution_channel',
        'depot_group',
        'price_group',
        'en_name',
        'kh_name',
        'credit_balance',
        'currency',
        'tax_number',
        'total_orders',
        'created_at',
        'sync_state',
      ]) {
        raw.execute('ALTER TABLE depots DROP COLUMN $column;');
      }
      raw.execute('ALTER TABLE depots DROP COLUMN territory_type;');
      raw.execute('ALTER TABLE depots DROP COLUMN geofence_radius_override;');
      raw.execute('PRAGMA user_version = 6;');
      raw.dispose();
    }

    test('an existing depot survives the upgrade with new columns null',
        () async {
      await createV6Fixture();

      // Seed a v6 depot, as a real device would have.
      final raw = sqlite.sqlite3.open(dbFile.path);
      raw.execute('''
        INSERT INTO depots (
          id, sap_depot_id, depot_code, shop_name, owner_name, phone,
          address, province, district, territory, latitude, longitude,
          credit_limit, status, assigned_rep_id, assigned_rep_name, updated_at
        ) VALUES (
          'cust-1', 'SAP-1', 'C-001', 'ISI Hardware', 'Sok Dara', '012345678',
          'St 271', 'Phnom Penh', 'Toul Kork', 'T1', 11.55, 104.91,
          5000.0, 'active', 'rep-1', 'Rep One', '2026-07-15T00:00:00.000Z'
        );
      ''');
      raw.dispose();

      // Re-open through Drift → triggers onUpgrade 6 → 8.
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final depot = await db.select(db.depots).getSingle();

      // The upgrade must not lose the row or any of its data.
      expect(depot.id, 'cust-1');
      expect(depot.shopName, 'ISI Hardware');
      expect(depot.creditLimit, 5000.0);
      // Newly-added columns are null for pre-existing rows, by design.
      expect(depot.territoryType, isNull);
      expect(depot.geofenceRadiusOverride, isNull);
    });

    test('upgrade creates the route/visit tables and records the registry',
        () async {
      await createV6Fixture();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table';")
          .get();
      final tables = rows.map((r) => r.data['name'] as String).toSet();

      expect(tables, containsAll(['routes', 'route_stops', 'visit_check_ins']));
      expect(
        await db.appMetadataDao.getValue(SchemaMetadataKeys.schemaVersion),
        '$kCurrentSchemaVersion',
      );
      expect(
        await db.appMetadataDao.getValue(SchemaMetadataKeys.lastMigratedFrom),
        '6',
      );
    });

    test('the upgraded database still accepts writes to the new tables',
        () async {
      await createV6Fixture();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      await db.into(db.routes).insert(
            RoutesCompanion.insert(
              id: 'route-1',
              name: 'R1',
              repId: 'rep-1',
              repName: 'Rep',
              territory: 'T1',
              visitDate: DateTime.utc(2026, 7, 15),
              plannedStart: DateTime.utc(2026, 7, 15, 8),
              plannedEnd: DateTime.utc(2026, 7, 15, 17),
              status: 'planned',
            ),
          );

      expect(await db.select(db.routes).get(), hasLength(1));
    });
  });

  group('v9 → v10 upgrade: counted_quantity becomes stock_level', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('isi_migration_v10');
      dbFile = File(p.join(tempDir.path, 'app.db'));
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    /// Fabricates a v9 database on disk with legacy quantity-based stock rows.
    ///
    /// Like the v6 fixture above, v9 is reconstructed from the current schema
    /// by removing exactly what v10 adds (depot_id, stock_level) and restoring
    /// what it drops (counted_quantity), then rewinding `user_version` — the
    /// base DDL stays Drift's own.
    Future<void> createV9Fixture() async {
      final setup = AppDatabase(NativeDatabase(dbFile));
      await setup.customStatement('SELECT 1;'); // force open → onCreate (v10)
      await setup.close();

      final raw = sqlite.sqlite3.open(dbFile.path);
      raw.execute('DROP INDEX IF EXISTS idx_visit_stock_updates_depot;');
      raw.execute('ALTER TABLE visit_stock_updates DROP COLUMN depot_id;');
      raw.execute('ALTER TABLE visit_stock_updates DROP COLUMN stock_level;');
      raw.execute('ALTER TABLE visit_stock_updates '
          'ADD COLUMN counted_quantity REAL NOT NULL DEFAULT 0;');

      // Seed the FK chain a real device would have, then two legacy counts:
      // one out-of-stock, one counted-in-stock.
      raw.execute('''
        INSERT INTO depots (
          id, sap_depot_id, depot_code, shop_name, owner_name, phone,
          address, province, district, territory, latitude, longitude,
          credit_limit, status, assigned_rep_id, assigned_rep_name, updated_at
        ) VALUES (
          'cust-1', 'SAP-1', 'C-001', 'ISI Hardware', 'Sok Dara', '012345678',
          'St 271', 'Phnom Penh', 'Toul Kork', 'T1', 11.55, 104.91,
          5000.0, 'active', 'rep-1', 'Rep One', '2026-07-15T00:00:00.000Z'
        );
      ''');
      const iso = '2026-07-15T00:00:00.000Z';
      raw.execute('''
        INSERT INTO routes (
          id, updated_at, deleted, sync_state, dirty, name, rep_id, rep_name,
          territory, visit_date, planned_start, planned_end, status
        ) VALUES ('route-1', '$iso', 0, 'synced', 0, 'R1', 'rep-1', 'Rep',
          'T1', '$iso', '$iso', '$iso', 'planned');
      ''');
      raw.execute('''
        INSERT INTO route_stops (
          id, updated_at, deleted, sync_state, dirty, route_id, depot_id,
          sequence, planned_arrival, planned_departure, status
        ) VALUES ('stop-1', '$iso', 0, 'synced', 0, 'route-1', 'cust-1', 1,
          '$iso', '$iso', 'pending');
      ''');
      for (final (id, qty) in [('su-out', 0.0), ('su-counted', 42.0)]) {
        raw.execute('''
          INSERT INTO visit_stock_updates (
            id, updated_at, deleted, sync_state, dirty, stop_id, product_id,
            product_name, notes, counted_quantity
          ) VALUES ('$id', '$iso', 0, 'dirty', 1, 'stop-1', 'p-1', 'Rebar',
            'note-$id', $qty);
        ''');
      }
      raw.execute('PRAGMA user_version = 9;');
      raw.dispose();
    }

    test('legacy counts survive as conservative stock levels', () async {
      await createV9Fixture();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final rows = await db.select(db.visitStockUpdates).get();
      final byId = {for (final r in rows) r.id: r};

      // 0 on the shelf → low; a positive count → medium (a raw quantity
      // carries no defensible medium/high boundary).
      expect(byId['su-out']!.stockLevel, 'low');
      expect(byId['su-counted']!.stockLevel, 'medium');

      // Nothing else about the rows is lost — including sync bookkeeping, so
      // a capture pending push before the upgrade still pushes after it.
      expect(byId['su-out']!.notes, 'note-su-out');
      expect(byId['su-out']!.syncState, 'dirty');
      expect(byId['su-out']!.dirty, isTrue);
      expect(byId['su-out']!.stopId, 'stop-1');
      expect(byId['su-out']!.depotId, isNull);
    });

    test('the upgraded table accepts depot-scoped rows (no stop)', () async {
      await createV9Fixture();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      await db.into(db.visitStockUpdates).insert(
            VisitStockUpdatesCompanion.insert(
              id: 'su-depot',
              depotId: const Value('cust-1'),
              productId: 'p-2',
              productName: 'Channel 100',
              stockLevel: 'high',
            ),
          );

      final row = await (db.select(db.visitStockUpdates)
            ..where((t) => t.id.equals('su-depot')))
          .getSingle();
      expect(row.stopId, isNull);
      expect(row.depotId, 'cust-1');
      expect(row.stockLevel, 'high');
    });
  });
}
