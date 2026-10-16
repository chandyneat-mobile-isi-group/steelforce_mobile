// ignore_for_file: experimental_member_use
part of '../schema_migrations.dart';

/// Schema steps v13–v18: workflow state, cart pricing snapshots, and the ADR-011 flat mirror.
/// Keyed by the version each upgrades *to*; see [_stepwiseMigrations].
final Map<int, SchemaMigrationStep> _stepsV13toV18 = <int, SchemaMigrationStep>{
  // v13 (T1.5b): the resume pointer — the last live table in `routes.db`.
  //
  // Separate from v12 so a failure here leaves a coherent Orders schema rather
  // than a half-built cutover, matching the v7/v8 split.
  13: (m, db) async => m.createTable(db.workflowState),
  // v14: catalog taxonomy reset — no schema change, a data reset.
  //
  // The demo catalog's categories moved from invented steel groupings to the
  // ones derived from SAP's material master, so every `category_id` on disk
  // changed. Categories carry no tombstone (they are reference data replaced
  // wholesale on sync, not a syncable entity), so the retired rows would
  // survive and orphan `categoriesWithProducts()` — the product finder would
  // open on categories that dead-end on the first tap.
  //
  // Products go too: theirs point at category ids that no longer exist, which
  // reads as "catalog populated" while every guided-filter query returns
  // nothing. Child rows are deleted ahead of products because prices/stock
  // carry a foreign key onto it.
  //
  // Clearing `catalog_sync_meta` is the load-bearing line: `getLastSyncedAt`
  // is what `syncIfNeeded()` uses to choose initial vs delta, so leaving it
  // set would delta against the tables just emptied and repopulate almost
  // nothing.
  14: (m, db) async {
    await db.customStatement('DELETE FROM prices;');
    await db.customStatement('DELETE FROM stock;');
    await db.customStatement('DELETE FROM favorites;');
    await db.customStatement('DELETE FROM recent_products;');
    await db.customStatement('DELETE FROM products;');
    await db.customStatement('DELETE FROM categories;');
    await db.customStatement('DELETE FROM catalog_sync_meta;');
  },
  // v15: localisation and ERP master-data columns on the catalog.
  //
  // Products gain the Khmer name, colour, specification and SAP creation date;
  // categories become a real taxonomy node (SAP code, both names, description,
  // icon, active flag, timestamps) instead of an id/name/order triple.
  //
  // Every column is added with a default or as nullable, so this is a pure
  // widening — existing rows stay valid and no data is rewritten. The catalog
  // is re-pulled from SAP anyway; the sync watermark is cleared at the end so
  // the next open backfills the new columns rather than deltaing against rows
  // that predate them.
  15: (m, db) async {
    // Only add what is genuinely missing.
    //
    // A walk starting below v4 hits `createTable(categories/products)` first,
    // and `createTable` emits the table's *current* definition — which already
    // contains these columns. Re-adding them then fails with "duplicate column
    // name" and strands the upgrade. Same trap v10 documents for
    // `visit_stock_updates`; the fix is to ask the database what it actually
    // has rather than assuming what version it came from.
    Future<Set<String>> columnsOf(String table) async {
      final rows = await db.customSelect("PRAGMA table_info('$table');").get();
      return rows.map((r) => r.data['name'] as String).toSet();
    }

    Future<void> addMissing(
      TableInfo<Table, dynamic> table,
      Set<String> existing,
      List<GeneratedColumn<Object>> columns,
    ) async {
      for (final column in columns) {
        if (existing.contains(column.name)) continue;
        await m.addColumn(table, column);
      }
    }

    await addMissing(db.products, await columnsOf('products'), [
      db.products.nameKh,
      db.products.color,
      db.products.specification,
      db.products.createdAt,
    ]);

    await addMissing(db.categories, await columnsOf('categories'), [
      db.categories.code,
      db.categories.nameKh,
      db.categories.description,
      db.categories.descriptionKh,
      db.categories.icon,
      db.categories.active,
      db.categories.createdAt,
      db.categories.updatedAt,
    ]);

    // Forces the next sync down the initial path so the widened columns are
    // populated — a delta would only touch rows SAP happens to have changed.
    await db.customStatement('DELETE FROM catalog_sync_meta;');
  },
  // v16: `depots.sap_depot_id` becomes nullable.
  //
  // The column was `text().unique()` and the API mapper collapsed a missing
  // SAP id to `''`. SQLite treats every NULL as distinct but `''` as one
  // value, so the *second* depot without a SAP id violated the constraint
  // and aborted the entire sync batch with
  // `UNIQUE constraint failed: depots.sap_depot_id`. That is the normal
  // case, not an edge one: a depot registered in the field has no SAP
  // identity until it is approved and pushed, so a fresh territory is mostly
  // `PendingApproval` rows with none.
  //
  // `alterTable` recreates the table with the current definition and copies
  // the data across, because SQLite cannot drop a NOT NULL constraint in
  // place.
  16: (m, db) async {
    await m.alterTable(TableMigration(db.depots));

    // Existing placeholders become real absences, so they stop competing for
    // the single `''` slot the old constraint allowed.
    await db
        .customSelect(
          "UPDATE depots SET sap_depot_id = NULL "
          "WHERE sap_depot_id = '';",
        )
        .get();
  },

  // v17: cart lines carry their own agreed price and fulfillment terms.
  //
  // Both columns are additive and nullable, so this is a pure `addColumn` with
  // no data rewrite and no destructive step. Existing rows stay NULL, which the
  // repository reads as "price this line from the live catalog row" — exactly
  // the behaviour those rows already had. A rep who upgrades mid-visit finds
  // their cart unchanged.
  //
  // Why a snapshot at all: `prices` is SAP-controlled and replaced wholesale on
  // sync, so a quotation saved on Monday re-priced itself on Tuesday. The
  // stored `quotations.total` then disagreed with the lines rendered under it,
  // and the PDF the depot was holding disagreed with both.
  17: (m, db) async {
    await _addColumnIfMissing(m, db, db.cartItems, db.cartItems.unitPrice);
    await _addColumnIfMissing(
        m, db, db.cartItems, db.cartItems.fulfillmentJson);
  },

  // v18 (ADR-011): the local database becomes a flat mirror of what the
  // backend sends, instead of re-enforcing relationships the backend already
  // enforced before the row was ever transmitted.
  //
  // This removes constraints. Nothing is dropped, no column changes type, and
  // every row is copied across — `alterTable` recreates each table from its
  // current Dart definition (now without the foreign key) and moves the data.
  //
  // ## Why, concretely
  //
  // Two verified data-loss paths, both triggered by ordinary operation:
  //
  //   1. `route_stops.depot_id -> depots` aborted the *whole* route
  //      transaction (`SqliteException(787)`) when a single stop referenced a
  //      depot the directory had not pulled yet. The route feed and the
  //      depot feed are separate, independently-paged endpoints, so this is
  //      routine — and it cost the rep every stop of the day, not one.
  //
  //   2. The `visit_* -> route_stops ON DELETE CASCADE` chain silently deleted
  //      captured check-ins, notes and photos whenever route sync refreshed a
  //      route, because the refresh replaces a route's stops. The backend
  //      documents re-sending the full set as expected behaviour
  //      (`docs/integrations/backend-document.md` §5.2), so this fired on a normal delta and
  //      destroyed first-hand field work that had not been pushed yet.
  //
  // The constraints that have no such path are deliberately kept — see the
  // foreign-key test for the surviving set and the reason each one earns it.
  18: (m, db) async {
    // The route feed's own depot rows, so a stop renders without the
    // depot directory having synced first.
    await m.createTable(db.routeDepots);

    // Backfill from the directory for stops that already exist on this device,
    // so an upgrading rep sees exactly what they saw before rather than a
    // screen of blank stop cards until the next route sync lands.
    //
    // `territory_type` falls back to 'urban' to preserve the fail-closed
    // geofence default documented on `kUnknownTerritoryFallback` — urban is the
    // tightest radius, so an unknown territory blocks a check-in rather than
    // waving it through.
    await db.customStatement(
      'INSERT OR IGNORE INTO route_depots '
      '(id, name, name_kh, code, contact, phone, address, territory, '
      'territory_type, latitude, longitude, geofence_radius_override) '
      'SELECT c.id, c.shop_name, COALESCE(c.kh_name, \'\'), c.depot_code, '
      'c.owner_name, c.phone, c.address, c.territory, '
      "COALESCE(c.territory_type, 'urban'), c.latitude, c.longitude, "
      'c.geofence_radius_override '
      'FROM depots c '
      'WHERE c.id IN (SELECT DISTINCT depot_id FROM route_stops);',
    );

    // Depot child tables — orphans here are invisible, not corrupting.
    await m.alterTable(TableMigration(db.depotContacts));
    await m.alterTable(TableMigration(db.depotNotes));
    await m.alterTable(TableMigration(db.depotActivities));
    await m.alterTable(TableMigration(db.depotFavorites));
    await m.alterTable(TableMigration(db.depotRecent));

    // Route stops (failure 1) and the fraud-flag -> stop cascade (failure 2,
    // applied to compliance evidence).
    await m.alterTable(TableMigration(db.routeStops));
    await m.alterTable(TableMigration(db.fraudFlags));

    // Visit captures (failure 2).
    await m.alterTable(TableMigration(db.visitCheckIns));
    await m.alterTable(TableMigration(db.visitCheckOuts));
    await m.alterTable(TableMigration(db.visitOrderLines));
    await m.alterTable(TableMigration(db.visitStockUpdates));
    await m.alterTable(TableMigration(db.visitReturns));
    await m.alterTable(TableMigration(db.visitCollections));
    await m.alterTable(TableMigration(db.visitNotes));
    await m.alterTable(TableMigration(db.visitPhotos));
  },
};
