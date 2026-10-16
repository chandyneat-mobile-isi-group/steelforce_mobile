// ignore_for_file: experimental_member_use
part of 'schema_migrations.dart';

// The customer → depot physical rename (v23), run before the stepwise loop on
// every upgrade. Split out of `schema_migrations.dart`.

/// Physical table renames from the customer -> depot migration, old -> new.
///
/// Order is irrelevant: each rename is guarded on what the database actually
/// has, so the set can be replayed against a database in any state.
const Map<String, String> _kLegacyDepotTableRenames = <String, String>{
  'customers': 'depots',
  'customer_activities': 'depot_activities',
  'customer_contacts': 'depot_contacts',
  'customer_favorites': 'depot_favorites',
  'customer_notes': 'depot_notes',
  'customer_recent': 'depot_recent',
  'customer_sync_meta': 'depot_sync_meta',
  'route_customers': 'route_depots',
};

/// Column renames, keyed by the table's **new** name — these run after the
/// table renames above.
///
/// `customer_id` is the key the whole app addresses a depot by, so it reaches
/// well past the depot's own tables: a cart, a quotation, a sales order and a
/// resumable workflow each carry one.
const Map<String, Map<String, String>> _kLegacyDepotColumnRenames =
    <String, Map<String, String>>{
  'depots': <String, String>{
    'customer_code': 'depot_code',
    'customer_group': 'depot_group',
    'sap_customer_id': 'sap_depot_id',
  },
  'depot_activities': <String, String>{'customer_id': 'depot_id'},
  'depot_contacts': <String, String>{'customer_id': 'depot_id'},
  'depot_favorites': <String, String>{'customer_id': 'depot_id'},
  'depot_notes': <String, String>{'customer_id': 'depot_id'},
  'depot_recent': <String, String>{'customer_id': 'depot_id'},
  'cart_items': <String, String>{'customer_id': 'depot_id'},
  'quotations': <String, String>{'customer_id': 'depot_id'},
  'sales_orders': <String, String>{'customer_id': 'depot_id'},
  'workflow_state': <String, String>{'customer_id': 'depot_id'},
  'route_stops': <String, String>{'customer_id': 'depot_id'},
  'visit_check_ins': <String, String>{
    'distance_from_customer': 'distance_from_depot',
  },
};

/// Index renames. SQLite has no `ALTER INDEX`, so each is a drop and a create.
///
/// A renamed table keeps its indexes — still under the old name, still doing
/// their job — so this is not about query speed. It is so that a device that
/// upgraded and a device installed fresh end up with the *same* names, and a
/// later migration can address an index without knowing which it is talking to.
const Map<String, String> _kLegacyDepotIndexRenames = <String, String>{
  'idx_customers_territory': 'idx_depots_territory',
  'idx_customers_rep': 'idx_depots_rep',
  'idx_customers_status': 'idx_depots_status',
  'idx_customers_sales_org': 'idx_depots_sales_org',
  'idx_customers_division': 'idx_depots_division',
  'idx_customer_activities_customer': 'idx_depot_activities_depot',
  'idx_customer_contacts_customer': 'idx_depot_contacts_depot',
  'idx_customer_notes_customer': 'idx_depot_notes_depot',
  'idx_route_stops_customer': 'idx_route_stops_depot',
};

/// Renames the pre-depot physical schema in place, preserving every row.
///
/// Runs before the stepwise loop on every upgrade, and does nothing at all to a
/// database that never carried the old names — including one just built by
/// `createAll`, which already uses the new ones.
///
/// Why a rename rather than a drop and re-sync: most of these tables mirror SAP
/// and could be re-pulled, but `cart_items`, `quotations`, `sales_orders` and
/// `workflow_state` hold a rep's own un-synced work. Recreating them would
/// discard an order taken in a shop with no signal — the one thing
/// offline-first exists to prevent (ADR-0002).
///
/// Every operation is guarded on what the database actually has rather than on
/// the version it claims, so a partially-applied upgrade can be replayed.
Future<void> _renameLegacyDepotSchema(AppDatabase db) async {
  for (final entry in _kLegacyDepotTableRenames.entries) {
    if (!await _tableExists(db, entry.key)) continue;
    if (await _tableExists(db, entry.value)) continue;
    await db.customStatement(
        'ALTER TABLE "${entry.key}" RENAME TO "${entry.value}";');
  }

  for (final table in _kLegacyDepotColumnRenames.entries) {
    if (!await _tableExists(db, table.key)) continue;
    for (final column in table.value.entries) {
      if (!await _columnExists(db, table.key, column.key)) continue;
      if (await _columnExists(db, table.key, column.value)) continue;
      await db.customStatement('ALTER TABLE "${table.key}" '
          'RENAME COLUMN "${column.key}" TO "${column.value}";');
    }
  }

  for (final entry in _kLegacyDepotIndexRenames.entries) {
    final rows = await db.customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?;",
      variables: [Variable<String>(entry.key)],
    ).get();
    if (rows.isEmpty) continue;
    final sql = rows.first.read<String?>('sql');
    // A null `sql` is an index SQLite created itself to back a UNIQUE
    // constraint. It is not ours to rename, and dropping it would drop the
    // constraint with it.
    if (sql == null) continue;

    // `ALTER TABLE ... RENAME` already rewrote the table and column names
    // inside this definition; only the index's own name is stale. The table and
    // column passes below are belt-and-braces for an older SQLite that did not,
    // where re-creating the index verbatim would fail on a table that no longer
    // answers to that name and abort the whole upgrade.
    var rebuilt = sql.replaceFirst(entry.key, entry.value);
    _kLegacyDepotTableRenames.forEach((old, renamed) {
      rebuilt = rebuilt.replaceAll('"$old"', '"$renamed"');
    });
    for (final columns in _kLegacyDepotColumnRenames.values) {
      columns.forEach((old, renamed) {
        rebuilt = rebuilt.replaceAll('"$old"', '"$renamed"');
      });
    }

    await db.customStatement('DROP INDEX IF EXISTS "${entry.key}";');
    await db.customStatement('$rebuilt;');
  }
}
