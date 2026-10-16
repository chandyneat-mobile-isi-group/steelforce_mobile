import 'package:drift/drift.dart';

/// Offline product catalog master data (Blueprint Layer 1), ported from the
/// legacy `catalog.db` into the single encrypted database. SAP-controlled:
/// replaced wholesale on sync. Transactional tables (cart, quotations, sales
/// orders, sync queue) are ported in a separate slice.

class Categories extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();

  /// SAP `ProductGroup` / `MaterialGroupName`. Stable across display renames,
  /// so sync matches on this rather than on a name the sales team may reword.
  TextColumn get code => text().withDefault(const Constant(''))();

  /// English display name. `name` keeps its original column so existing reads
  /// and the v14 data survive the upgrade untouched.
  TextColumn get name => text()();

  /// Khmer display name. Empty when SAP carries no Khmer text — the entity
  /// falls back to English rather than rendering a blank label.
  TextColumn get nameKh => text().withDefault(const Constant(''))();

  TextColumn get description => text().nullable()();
  TextColumn get descriptionKh => text().nullable()();

  /// Icon *key*, resolved to a glyph in presentation. Storing a key rather
  /// than a codepoint lets SAP publish a category the app has never seen
  /// without shipping an update.
  TextColumn get icon => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Retired categories stay for historical quotation lines to resolve
  /// against, but are never offered for new selection.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_products_code', columns: {#code})
@TableIndex(name: 'idx_products_barcode', columns: {#barcode})
@TableIndex(name: 'idx_products_category', columns: {#categoryId})
@TableIndex(name: 'idx_products_brand', columns: {#brand})
@TableIndex(name: 'idx_products_sku', columns: {#sku})
@TableIndex(name: 'idx_products_warehouse', columns: {#warehouseCode})
@TableIndex(name: 'idx_products_family', columns: {#familyId})
class Products extends Table {
  @override
  String get tableName => 'products';

  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get familyName => text()();
  TextColumn get code => text()();
  TextColumn get sku => text()();
  TextColumn get materialCode => text()();
  TextColumn get barcode => text()();

  /// SAP `MaterialDes`.
  TextColumn get name => text()();

  /// SAP `MaterialDesKH`. Defaulted rather than nullable so every read gets a
  /// string and the fallback lives in one place ([LocalizedText.resolve]).
  TextColumn get nameKh => text().withDefault(const Constant(''))();

  TextColumn get description => text()();

  /// Top colour / finish — the last thing a roofing depot chooses, and
  /// distinct from `grade`.
  TextColumn get color => text().withDefault(const Constant(''))();

  /// Free-text spec for rows the structured dimension columns don't fully
  /// describe.
  TextColumn get specification => text().withDefault(const Constant(''))();

  TextColumn get categoryId => text()();
  TextColumn get subCategory => text()();
  TextColumn get brand => text()();
  TextColumn get grade => text()();
  TextColumn get material => text()();
  TextColumn get size => text()();
  RealColumn get diameter => real()();
  RealColumn get thickness => real()();
  RealColumn get length => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  RealColumn get weight => real()();
  TextColumn get unit => text()();
  TextColumn get warehouseCode => text()();
  TextColumn get territory => text()();
  TextColumn get businessUnit => text()();
  TextColumn get imageUrl => text()();
  BoolColumn get isMto => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get updatedAt => dateTime()();

  /// SAP creation date. Nullable — the current extract doesn't carry it for
  /// every material, and a fabricated date would be worse than a null.
  DateTimeColumn get createdAt => dateTime().nullable()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  RealColumn get minStock => real().withDefault(const Constant(0))();
  RealColumn get maxStock => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Prices extends Table {
  @override
  String get tableName => 'prices';

  // Restored explicitly: drift_dev 2.31.0 + analyzer 10.2.0 silently emit no
  // foreign keys from `references()` above (docs/blueprint/web-architecture.md section 8).
  // The `references()` calls are kept — they still drive drift's Dart-side
  // relation API — but the SQL constraint now comes from here. Remove this
  // override once the generator is fixed, and verify with the FK tests.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (product_id) REFERENCES products (id)',
      ];

  TextColumn get productId => text().references(Products, #id)();
  RealColumn get costPrice => real()();
  RealColumn get standardPrice => real()();
  RealColumn get wholesalePrice => real()();
  RealColumn get dealerPrice => real()();
  RealColumn get vipPrice => real()();
  RealColumn get creditPrice => real()();
  RealColumn get cashPrice => real()();
  RealColumn get promotionPrice => real().nullable()();
  TextColumn get promotionType => text().nullable()();
  TextColumn get promotionLabel => text().nullable()();
  TextColumn get currency => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}

@TableIndex(name: 'idx_stock_warehouse', columns: {#warehouseCode})
class Stock extends Table {
  @override
  String get tableName => 'stock';

  // Restored explicitly: drift_dev 2.31.0 + analyzer 10.2.0 silently emit no
  // foreign keys from `references()` above (docs/blueprint/web-architecture.md section 8).
  // The `references()` calls are kept — they still drive drift's Dart-side
  // relation API — but the SQL constraint now comes from here. Remove this
  // override once the generator is fixed, and verify with the FK tests.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (product_id) REFERENCES products (id)',
      ];

  TextColumn get productId => text().references(Products, #id)();
  TextColumn get warehouseCode => text()();
  RealColumn get quantity => real()();
  RealColumn get reserved => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId, warehouseCode};
}

// ── Local UI state + sync bookkeeping (read side) ────────────────────

class ProductFavorites extends Table {
  @override
  String get tableName => 'favorites';

  // Restored explicitly: drift_dev 2.31.0 + analyzer 10.2.0 silently emit no
  // foreign keys from `references()` above (docs/blueprint/web-architecture.md section 8).
  // The `references()` calls are kept — they still drive drift's Dart-side
  // relation API — but the SQL constraint now comes from here. Remove this
  // override once the generator is fixed, and verify with the FK tests.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (product_id) REFERENCES products (id)',
      ];

  TextColumn get productId => text().references(Products, #id)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}

class RecentProducts extends Table {
  @override
  String get tableName => 'recent_products';

  // Restored explicitly: drift_dev 2.31.0 + analyzer 10.2.0 silently emit no
  // foreign keys from `references()` above (docs/blueprint/web-architecture.md section 8).
  // The `references()` calls are kept — they still drive drift's Dart-side
  // relation API — but the SQL constraint now comes from here. Remove this
  // override once the generator is fixed, and verify with the FK tests.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (product_id) REFERENCES products (id)',
      ];

  TextColumn get productId => text().references(Products, #id)();
  DateTimeColumn get viewedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}

class CatalogSyncMeta extends Table {
  @override
  String get tableName => 'catalog_sync_meta';

  TextColumn get entity => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}
