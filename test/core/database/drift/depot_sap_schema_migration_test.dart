import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Covers schema v9: the SAP sales-area and commercial columns added to
/// `depots` so the directory can be filtered by Sales Organization and
/// Division, and so the mock datasource can later be swapped for a real SAP one
/// without another schema change (ADR-009).
///
/// `docs/blueprint/local-storage-architecture.md` §5 requires every migration step to ship with a test
/// that upgrades a fixture of the *previous* version and proves data survives.
/// That is the `v8 → v9` group below.
///
/// Runs on a plain `NativeDatabase` (no SQLCipher) so it works on host CI.
void main() {
  group('v9 schema — SAP columns exist after onCreate', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('registry constant covers the v9 SAP columns', () {
      // v9 landed the SAP sales-area columns; later bumps (v10 stock levels)
      // move the constant past it, so assert "at least", not equality.
      expect(kCurrentSchemaVersion, greaterThanOrEqualTo(9));
    });

    test('depots carries every new SAP column', () async {
      final rows = await db.customSelect('PRAGMA table_info(depots);').get();
      final columns = rows.map((r) => r.data['name'] as String).toSet();

      expect(
        columns,
        containsAll([
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
        ]),
      );
    });

    test('the sales-area filter indexes exist', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='index';")
          .get();
      final indexes = rows.map((r) => r.data['name'] as String).toSet();

      // Without these, filtering a large directory by sales area degrades to a
      // full table scan (DATABASE_GUIDE.md §3).
      expect(indexes,
          containsAll(['idx_depots_sales_org', 'idx_depots_division']));
    });

    test('defaults are sane for a row that supplies none of them', () async {
      await db.into(db.depots).insert(
            DepotsCompanion.insert(
              id: 'c1',
              sapDepotId: Value('SAP-1'),
              depotCode: 'C-001',
              shopName: 'Shop',
              ownerName: 'Owner',
              phone: '012',
              address: 'St 1',
              province: 'Phnom Penh',
              district: 'Chamkarmon',
              territory: 'PP',
              latitude: 11.5,
              longitude: 104.9,
              creditLimit: 0,
              status: 'active',
              assignedRepId: 'r1',
              assignedRepName: 'Rep',
              updatedAt: DateTime.utc(2026, 7, 21),
            ),
          );

      final row = await db.select(db.depots).getSingle();

      expect(row.creditBalance, 0);
      expect(row.currency, 'USD');
      expect(row.totalOrders, 0);
      expect(row.syncState, 'synced');
      // Sales area is genuinely unknown until SAP supplies it — null, not ''.
      expect(row.salesOrg, isNull);
      expect(row.division, isNull);
    });
  });

  group('v8 → v9 upgrade preserves data (DATABASE_GUIDE §5)', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('isi_v9_migration_test');
      dbFile = File(p.join(tempDir.path, 'app.db'));
    });

    tearDown(() async {
      // Windows keeps a lock on the file briefly after close; a failed cleanup
      // of a temp directory must not mask the assertion that actually ran.
      try {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Best-effort — the OS reclaims the temp dir.
      }
    });

    /// Fabricates a v8 database on disk.
    ///
    /// Same approach as the v6 fixture in `route_visit_schema_migration_test`:
    /// build the current schema with Drift's own DDL, then remove exactly what
    /// v9 adds and rewind `user_version`. Keeps the fixture honest rather than
    /// hand-writing DDL that could drift from reality.
    Future<void> createV8Fixture() async {
      final setup = AppDatabase(NativeDatabase(dbFile));
      await setup.customStatement('SELECT 1;'); // force open → onCreate (v9)
      await setup.close();

      final raw = sqlite.sqlite3.open(dbFile.path);
      // Indexes must go first: SQLite refuses to drop a column that an index
      // still references ("error in index ... after drop column").
      raw.execute('DROP INDEX IF EXISTS idx_depots_sales_org;');
      raw.execute('DROP INDEX IF EXISTS idx_depots_division;');
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
      raw.execute('PRAGMA user_version = 8;');
      raw.dispose();
    }

    /// Seeds a depot exactly as a v8 device would hold it.
    void seedV8Depot() {
      final raw = sqlite.sqlite3.open(dbFile.path);
      raw.execute('''
        INSERT INTO depots (
          id, sap_depot_id, depot_code, shop_name, owner_name, phone,
          address, province, district, territory, latitude, longitude,
          credit_limit, status, assigned_rep_id, assigned_rep_name, updated_at,
          lifetime_value
        ) VALUES (
          'cust-1', 'SAP-1', 'C-001', 'ISI Hardware', 'Sok Dara', '012345678',
          'St 271', 'Phnom Penh', 'Toul Kork', 'T1', 11.55, 104.91,
          5000.0, 'active', 'rep-1', 'Rep One', '2026-07-15T00:00:00.000Z',
          12345.67
        );
      ''');
      raw.dispose();
    }

    test('an existing depot survives with all v8 data intact', () async {
      await createV8Fixture();
      seedV8Depot();

      // Re-open through Drift → triggers onUpgrade 8 → 9.
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final depot = await db.select(db.depots).getSingle();

      // Nothing the user already had may be lost or altered.
      expect(depot.id, 'cust-1');
      expect(depot.sapDepotId, 'SAP-1');
      expect(depot.shopName, 'ISI Hardware');
      expect(depot.ownerName, 'Sok Dara');
      expect(depot.creditLimit, 5000.0);
      expect(depot.lifetimeValue, 12345.67);
      expect(depot.province, 'Phnom Penh');
    });

    test('new SAP columns come back null/defaulted for pre-existing rows',
        () async {
      await createV8Fixture();
      seedV8Depot();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final depot = await db.select(db.depots).getSingle();

      // A v8 row has no sales area — it must read as unknown, not as a
      // misleading empty string that would match a filter.
      expect(depot.salesOrg, isNull);
      expect(depot.division, isNull);
      expect(depot.distributionChannel, isNull);
      expect(depot.enName, isNull);
      expect(depot.taxNumber, isNull);
      // Defaulted columns take their declared default.
      expect(depot.creditBalance, 0);
      expect(depot.currency, 'USD');
      expect(depot.totalOrders, 0);
      expect(depot.syncState, 'synced');
    });

    test('the upgrade records the version registry', () async {
      await createV8Fixture();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      expect(
        await db.appMetadataDao.getValue(SchemaMetadataKeys.schemaVersion),
        '$kCurrentSchemaVersion',
      );
      expect(
        await db.appMetadataDao.getValue(SchemaMetadataKeys.lastMigratedFrom),
        '8',
      );
    });

    test('the upgraded database accepts writes to the new columns', () async {
      await createV8Fixture();
      seedV8Depot();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      await (db.update(db.depots)..where((t) => t.id.equals('cust-1'))).write(
        const DepotsCompanion(
          salesOrg: Value('PRD'),
          division: Value('STEEL'),
        ),
      );

      final depot = await db.select(db.depots).getSingle();
      expect(depot.salesOrg, 'PRD');
      expect(depot.division, 'STEEL');
    });

    test('the sales-area indexes are created by the upgrade, not just onCreate',
        () async {
      await createV8Fixture();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='index';")
          .get();
      final indexes = rows.map((r) => r.data['name'] as String).toSet();

      expect(indexes,
          containsAll(['idx_depots_sales_org', 'idx_depots_division']));
    });
  });
}
