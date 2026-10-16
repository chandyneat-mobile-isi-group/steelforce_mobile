import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v22 → v23: the customer -> depot rename reaches the physical schema.
///
/// The rename was applied to the *historical* migration steps — step 2 went
/// from `createTable(db.customers)` to `createTable(db.depots)` — without a
/// version bump. A device already on v22 therefore had tables physically named
/// `customers`, Drift saw `from == to` and ran nothing, and the first read
/// failed with `no such table: depots`. A fresh install worked, because
/// `onCreate` calls `createAll()` at the new names, which is what made this
/// look like a device problem rather than a schema one.
///
/// The rename runs before the stepwise loop rather than as step 23, because
/// steps 3..22 were rewritten to address `depots` too: a device on v10 would
/// otherwise run `ALTER TABLE depots` against a table still called `customers`.
///
/// It is a rename and not a drop-and-resync on purpose. `cart_items`,
/// `quotations`, `sales_orders` and `workflow_state` carry a rep's own unsynced
/// work, and an upgrade that recreated them would discard an order taken in a
/// shop with no signal.
///
/// ## Why [_v22CustomerTables] and [_v22CustomerColumns] are written out here
///
/// The first cut of this migration missed `route_stops.customer_id` and shipped
/// a second crash — `no such column: route_stops.depot_id` — because the list
/// of renames was assembled by reading the table definitions, and the reader
/// skipped every table declared with a mixin. A test whose fixture is built
/// from the same map the migration uses cannot catch that: both sides agree,
/// and both are wrong.
///
/// So these two constants are a frozen, independent record of what v22 actually
/// had on disk, taken from the schema as it shipped. The fixture is built from
/// them, and the assertions check the *migration* against them. A rename the
/// migration forgets is a test failure here rather than a crash on a handset.
const List<String> _v22CustomerTables = [
  'customers',
  'customer_activities',
  'customer_contacts',
  'customer_favorites',
  'customer_notes',
  'customer_recent',
  'customer_sync_meta',
  'route_customers',
];

/// Keyed by the v22 table name. Every column that v22 named after a customer.
const Map<String, Map<String, String>> _v22CustomerColumns = {
  'customers': {
    'customer_code': 'depot_code',
    'customer_group': 'depot_group',
    'sap_customer_id': 'sap_depot_id',
  },
  'customer_activities': {'customer_id': 'depot_id'},
  'customer_contacts': {'customer_id': 'depot_id'},
  'customer_favorites': {'customer_id': 'depot_id'},
  'customer_notes': {'customer_id': 'depot_id'},
  'customer_recent': {'customer_id': 'depot_id'},
  'cart_items': {'customer_id': 'depot_id'},
  'quotations': {'customer_id': 'depot_id'},
  'sales_orders': {'customer_id': 'depot_id'},
  'workflow_state': {'customer_id': 'depot_id'},
  'route_stops': {'customer_id': 'depot_id'},
  'visit_check_ins': {'distance_from_customer': 'distance_from_depot'},
};

String _v23TableFor(String v22Table) {
  if (!v22Table.startsWith('customer') && v22Table != 'route_customers') {
    return v22Table;
  }
  return switch (v22Table) {
    'customers' => 'depots',
    'route_customers' => 'route_depots',
    _ => v22Table.replaceFirst('customer', 'depot'),
  };
}

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_v23_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Builds a v22 database by creating the current schema, seeding it through
  /// Drift's own API, then renaming everything *back* to the v22 names and
  /// rewinding `user_version`.
  ///
  /// Seeding before the rewind rather than hand-writing a v22 `INSERT`: the row
  /// then cannot drift from what actually shipped, and the assertions below are
  /// about data a real device really would have had.
  Future<void> createV22Fixture() async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.into(setup.depots).insert(
          DepotsCompanion.insert(
            id: 'dep-1',
            depotCode: 'BP-884920',
            shopName: 'Phnom Penh Steel Outlet',
            ownerName: 'Yim Vithou',
            phone: '026407480',
            address: 'St. 218, Mean Chey',
            province: 'Phnom Penh',
            district: 'Mean Chey',
            territory: 'PP-CENTRAL',
            latitude: 11.5449,
            longitude: 104.9160,
            creditLimit: 50000,
            status: 'active',
            assignedRepId: 'rep-1',
            assignedRepName: 'Sok Dara',
            updatedAt: DateTime.utc(2026, 9, 1),
            sapDepotId: const Value('0000123456'),
            depotGroup: const Value('01'),
          ),
        );
    await setup.into(setup.routes).insert(
          RoutesCompanion.insert(
            id: 'route-1',
            name: 'PP Central — Tuesday',
            repId: 'rep-1',
            repName: 'Sok Dara',
            territory: 'PP-CENTRAL',
            visitDate: DateTime.utc(2026, 9, 16),
            plannedStart: DateTime.utc(2026, 9, 16, 8),
            plannedEnd: DateTime.utc(2026, 9, 16, 17),
            status: 'planned',
          ),
        );
    await setup.into(setup.routeStops).insert(
          RouteStopsCompanion.insert(
            id: 'stop-1',
            routeId: 'route-1',
            depotId: 'dep-1',
            sequence: 1,
            plannedArrival: Value(DateTime.utc(2026, 9, 16, 9)),
            plannedDeparture: Value(DateTime.utc(2026, 9, 16, 9, 30)),
            status: 'pending',
          ),
        );
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    // Columns first, then tables — the mirror image of the order the migration
    // applies them in. Driven by the frozen v22 record, so a rename the
    // migration forgets is still present in the fixture and still fails.
    for (final table in _v22CustomerColumns.entries) {
      final live = _v23TableFor(table.key);
      for (final column in table.value.entries) {
        raw.execute('ALTER TABLE "$live" RENAME COLUMN "${column.value}" '
            'TO "${column.key}";');
      }
    }
    for (final v22Table in _v22CustomerTables) {
      raw.execute('ALTER TABLE "${_v23TableFor(v22Table)}" '
          'RENAME TO "$v22Table";');
    }
    raw.execute('PRAGMA user_version = 22;');
    raw.dispose();
  }

  test('the upgrade runs and lands on the current version', () async {
    await createV22Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });

  // The schema-version pin moved on to
  // `quotation_admin_sync_v23_to_v24_migration_test.dart` with v24.

  test('every v22 table is renamed, and no old name survives', () async {
    await createV22Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table';")
        .get();
    final tables = rows.map((r) => r.read<String>('name')).toSet();

    for (final v22Table in _v22CustomerTables) {
      expect(tables, contains(_v23TableFor(v22Table)),
          reason: 'missing: ${_v23TableFor(v22Table)}');
      expect(tables, isNot(contains(v22Table)),
          reason: 'left behind: $v22Table');
    }
  });

  test('every v22 column is renamed, and no old name survives', () async {
    await createV22Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    for (final table in _v22CustomerColumns.entries) {
      final live = _v23TableFor(table.key);
      final info = await db.customSelect('PRAGMA table_info("$live");').get();
      final columns = info.map((r) => r.read<String>('name')).toSet();

      for (final column in table.value.entries) {
        expect(columns, contains(column.value),
            reason: '$live is missing ${column.value}');
        expect(columns, isNot(contains(column.key)),
            reason: '$live still carries ${column.key}');
      }
    }
  });

  test('the exact query that failed on the device now answers', () async {
    await createV22Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // `DepotDao.browse`, which surfaced as
    // "Failed to browse depots: no such table: depots".
    final depots = await db.customSelect(
        'SELECT * FROM "depots" WHERE "deleted" = ? '
        'ORDER BY "last_order_date" DESC LIMIT 31 OFFSET 0;',
        variables: [Variable<bool>(false)]).get();
    expect(depots, hasLength(1));
    expect(depots.first.read<String>('id'), 'dep-1');

    // The route load, which surfaced as the second crash —
    // "Failed to load all routes: no such column: route_stops.depot_id".
    final stops = await db
        .customSelect('SELECT "route_stops"."depot_id" AS d '
            'FROM "route_stops" ORDER BY "sequence";')
        .get();
    expect(stops, hasLength(1));
    expect(stops.first.read<String>('d'), 'dep-1');
  });

  test('the seeded rows survive the rename intact', () async {
    await createV22Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // The whole point of renaming rather than recreating: the rows are still
    // here, under the new column names, with nothing rewritten.
    final depot = await db.select(db.depots).getSingle();
    expect(depot.id, 'dep-1');
    expect(depot.depotCode, 'BP-884920');
    expect(depot.sapDepotId, '0000123456');
    expect(depot.depotGroup, '01');
    expect(depot.creditLimit, 50000);

    final stop = await db.select(db.routeStops).getSingle();
    expect(stop.depotId, 'dep-1');
    expect(stop.routeId, 'route-1');
  });

  test('the migrated schema matches a fresh install exactly', () async {
    // The invariant underneath every assertion above: however a device got
    // here, it must end up with the schema `createAll` would have built. This
    // is what catches a rename nobody thought to write a case for.
    await createV22Fixture();
    final migrated = AppDatabase(NativeDatabase(dbFile));
    final migratedShape = <String, List<String>>{};
    for (final row in await migrated
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name;")
        .get()) {
      final table = row.read<String>('name');
      final info =
          await migrated.customSelect('PRAGMA table_info("$table");').get();
      migratedShape[table] =
          (info.map((r) => r.read<String>('name')).toList()..sort());
    }
    await migrated.close();

    final freshFile = File(p.join(tempDir.path, 'fresh.db'));
    final fresh = AppDatabase(NativeDatabase(freshFile));
    final freshShape = <String, List<String>>{};
    for (final row in await fresh
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name;")
        .get()) {
      final table = row.read<String>('name');
      final info =
          await fresh.customSelect('PRAGMA table_info("$table");').get();
      freshShape[table] =
          (info.map((r) => r.read<String>('name')).toList()..sort());
    }
    await fresh.close();

    expect(migratedShape.keys.toSet(), freshShape.keys.toSet(),
        reason: 'table names diverge between upgrade and fresh install');
    for (final table in freshShape.keys) {
      expect(migratedShape[table], freshShape[table],
          reason: 'columns of $table diverge between upgrade and fresh '
              'install');
    }
  });

  test('no index keeps its pre-depot name', () async {
    await createV22Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND sql IS NOT NULL;")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toList();

    expect(names.where((n) => n.contains('customer')), isEmpty,
        reason: 'stale index names: $names');
  });

  test('replaying the upgrade changes nothing', () async {
    await createV22Fixture();

    final first = AppDatabase(NativeDatabase(dbFile));
    await first.customSelect('SELECT 1;').getSingle();
    await first.close();

    // A partially-applied upgrade has to be replayable, so rewind and reopen.
    // Every rename is guarded on what the database has rather than the version
    // it claims, so the second pass must be a no-op rather than an error.
    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('PRAGMA user_version = 22;');
    raw.dispose();

    final second = AppDatabase(NativeDatabase(dbFile));
    addTearDown(second.close);

    final row = await second.select(second.depots).getSingle();
    expect(row.id, 'dep-1');
    expect(row.depotCode, 'BP-884920');
  });

  test('a fresh install needs no rename and carries no customer names',
      () async {
    // No fixture: `onCreate` builds the current schema directly. That the two
    // paths had diverged is the whole bug, so this also guards the other
    // direction — a new table named after a customer would be caught here.
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%';")
        .get();
    final tables = rows.map((r) => r.read<String>('name')).toList();

    expect(tables, contains('depots'));
    expect(tables.where((t) => t.contains('customer')), isEmpty);

    for (final table in tables) {
      final info = await db.customSelect('PRAGMA table_info("$table");').get();
      final columns = info.map((r) => r.read<String>('name')).toList();
      expect(columns.where((c) => c.contains('customer')), isEmpty,
          reason: '$table still names a column after a customer');
    }

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });
}
