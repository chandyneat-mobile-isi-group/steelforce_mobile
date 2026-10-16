// ignore_for_file: experimental_member_use
part of '../schema_migrations.dart';

/// Schema steps v2–v12: the first feature entities ported into the encrypted database.
/// Keyed by the version each upgrades *to*; see [_stepwiseMigrations].
final Map<int, SchemaMigrationStep> _stepsV2toV12 = <int, SchemaMigrationStep>{
  // v2 (T2): first feature entity ported into the encrypted single DB.
  2: (m, db) async => m.createTable(db.depots),
  // v3 (T2): depot child tables (contacts, notes, activities, favorites,
  // recent, sync meta).
  3: (m, db) async {
    await m.createTable(db.depotContacts);
    await m.createTable(db.depotNotes);
    await m.createTable(db.depotActivities);
    await m.createTable(db.depotFavorites);
    await m.createTable(db.depotRecent);
    await m.createTable(db.depotSyncMeta);
  },
  // v4 (T3): product catalog master data.
  4: (m, db) async {
    await m.createTable(db.categories);
    await m.createTable(db.products);
    await m.createTable(db.prices);
    await m.createTable(db.stock);
  },
  // v5 (T3): catalog read-side state (favorites, recent, sync meta).
  5: (m, db) async {
    await m.createTable(db.productFavorites);
    await m.createTable(db.recentProducts);
    await m.createTable(db.catalogSyncMeta);
  },
  // v6 (T5): local cart.
  6: (m, db) async => m.createTable(db.cartItems),
  // v7 (T1.5): route domain, ported off the plaintext `routes.db`.
  //
  // The two depot columns are added *before* the route tables because
  // `route_stops.depot_id` is a real FK to `depots` — an integrity
  // guarantee the old three-database split made impossible (ADR-001).
  7: (m, db) async {
    await m.addColumn(db.depots, db.depots.territoryType);
    await m.addColumn(db.depots, db.depots.geofenceRadiusOverride);
    await m.createTable(db.routes);
    await m.createTable(db.routeStops);
    await m.createTable(db.locationSamples);
    await m.createTable(db.fraudFlags);
    await m.createTable(db.routeSyncMeta);
  },
  // v8 (T1.5): visit captures, ported off the plaintext `routes.db`. Separate
  // from v7 so a failure here leaves a coherent v7 schema rather than a
  // half-built route domain.
  8: (m, db) async {
    await m.createTable(db.visitCheckIns);
    await m.createTable(db.visitCheckOuts);
    await m.createTable(db.visitOrderLines);
    await m.createTable(db.visitStockUpdates);
    await m.createTable(db.visitReturns);
    await m.createTable(db.visitCollections);
    await m.createTable(db.visitNotes);
    await m.createTable(db.visitPhotos);
  },
  // v9: SAP sales-area and commercial attributes on `depots`.
  //
  // Purely additive — every column is nullable or defaulted, so existing rows
  // upgrade without a rewrite and no data is touched. The two indexes back the
  // Sales Organization / Division filters (DATABASE_GUIDE.md §3).
  9: (m, db) async {
    await m.addColumn(db.depots, db.depots.salesOrg);
    await m.addColumn(db.depots, db.depots.division);
    await m.addColumn(db.depots, db.depots.distributionChannel);
    await m.addColumn(db.depots, db.depots.depotGroup);
    await m.addColumn(db.depots, db.depots.priceGroup);
    await m.addColumn(db.depots, db.depots.enName);
    await m.addColumn(db.depots, db.depots.khName);
    await m.addColumn(db.depots, db.depots.creditBalance);
    await m.addColumn(db.depots, db.depots.currency);
    await m.addColumn(db.depots, db.depots.taxNumber);
    await m.addColumn(db.depots, db.depots.totalOrders);
    await m.addColumn(db.depots, db.depots.createdAt);
    await m.addColumn(db.depots, db.depots.syncState);

    // `IF NOT EXISTS` keeps the step re-runnable after a crash mid-upgrade,
    // which DATABASE_GUIDE.md §5 requires of every migration.
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_depots_sales_org '
      'ON depots (sales_org);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_depots_division '
      'ON depots (division);',
    );
  },
  // v10: three-tier stock status replaces numeric stock counting.
  //
  // `visit_stock_updates` is recreated (TableMigration) because two changes
  // can't be done additively: `stop_id` becomes nullable (depot counts have no
  // route stop) and `counted_quantity REAL` is dropped in favour of
  // `stock_level TEXT`. Existing counts are preserved, not discarded, via the
  // most conservative faithful mapping a raw count allows: 0 → 'low'
  // (out of stock), anything positive → 'medium' (stock was present, but a
  // unit count carries no defensible medium/high boundary). All other columns
  // — including the SyncableTable sync bookkeeping — copy across unchanged, so
  // a row captured offline before the upgrade still pushes after it.
  10: (m, db) async {
    // When the walk starts below v8, step 8's createTable already produced the
    // *current* (stock_level) shape — transforming a column that never existed
    // would fail, so the rebuild only runs for databases that really carry the
    // legacy quantity column.
    final columns = await db
        .customSelect("PRAGMA table_info('visit_stock_updates');")
        .get();
    final hasLegacyQuantity =
        columns.any((row) => row.data['name'] == 'counted_quantity');

    if (hasLegacyQuantity) {
      // TableMigration is drift's documented mechanism for column-shape
      // changes; marked experimental upstream but covered by the v9→v10
      // migration test.
      await m.alterTable(
        TableMigration(
          db.visitStockUpdates,
          newColumns: [db.visitStockUpdates.depotId],
          columnTransformer: {
            db.visitStockUpdates.stockLevel: const CustomExpression<String>(
              "CASE WHEN counted_quantity <= 0 THEN 'low' ELSE 'medium' END",
            ),
          },
        ),
      );
    }
    // TableMigration recreates the table; re-assert the stop index and add the
    // depot one. IF NOT EXISTS keeps the step re-runnable after a crash
    // mid-upgrade (DATABASE_GUIDE.md §5).
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_visit_stock_updates_stop '
      'ON visit_stock_updates (stop_id);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_visit_stock_updates_depot '
      'ON visit_stock_updates (depot_id);',
    );
  },
  // v11: per-line product customization on the local cart.
  //
  // Purely additive — a single nullable TEXT column holding the customization
  // JSON blob (measurements, appearance, drawing path, notes). `cart_items` is
  // local-only and never synced, so no sync bookkeeping is involved; existing
  // rows upgrade untouched (null = a plain catalog line).
  //
  // The existence guard is required, not defensive padding. `m.createTable` in
  // step 6 builds `cart_items` from the *current* table definition, which
  // already includes this column — so a device walking from below v6 arrives
  // here with the column present and `ALTER TABLE ... ADD COLUMN` fails with
  // "duplicate column name". Step 10 guards the same hazard the same way.
  //
  // (Latent until schema v12 shipped: before then no migration walk reached
  // step 11 from below v6 in the covered paths, so the bug never fired.)
  11: (m, db) async {
    final columns =
        await db.customSelect("PRAGMA table_info('cart_items');").get();
    final alreadyPresent =
        columns.any((row) => row.data['name'] == 'customization_json');
    if (alreadyPresent) return;
    await m.addColumn(db.cartItems, db.cartItems.customizationJson);
  },
  // v12 (T1.5b): Orders domain, ported off the plaintext `catalog.db`.
  //
  // Creates the tables only — no data is copied here. The import from the
  // legacy file is a one-shot bootstrap step (`LegacyOrdersImporter`), not a
  // migration, for the same reason v7/v8 did it that way: a migration runs
  // inside drift's schema transaction and must stay deterministic, while the
  // import has to reconcile rows and decide whether purging the plaintext
  // source is safe.
  //
  // The two indexes are the ones `catalog.db` carried; they back the queue's
  // status filter and its per-quotation lookup.
  12: (m, db) async {
    await m.createTable(db.quotations);
    await m.createTable(db.salesOrders);
    await m.createTable(db.syncQueue);
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status '
      'ON sync_queue (status);',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_quotation '
      'ON sync_queue (quotation_id);',
    );
  },
};
