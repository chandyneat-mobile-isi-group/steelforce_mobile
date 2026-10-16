// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_dao.dart';

// ignore_for_file: type=lint
mixin _$CatalogDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $PricesTable get prices => attachedDatabase.prices;
  $StockTable get stock => attachedDatabase.stock;
  $ProductFavoritesTable get productFavorites =>
      attachedDatabase.productFavorites;
  $RecentProductsTable get recentProducts => attachedDatabase.recentProducts;
  $CatalogSyncMetaTable get catalogSyncMeta => attachedDatabase.catalogSyncMeta;
  CatalogDaoManager get managers => CatalogDaoManager(this);
}

class CatalogDaoManager {
  final _$CatalogDaoMixin _db;
  CatalogDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$PricesTableTableManager get prices =>
      $$PricesTableTableManager(_db.attachedDatabase, _db.prices);
  $$StockTableTableManager get stock =>
      $$StockTableTableManager(_db.attachedDatabase, _db.stock);
  $$ProductFavoritesTableTableManager get productFavorites =>
      $$ProductFavoritesTableTableManager(
          _db.attachedDatabase, _db.productFavorites);
  $$RecentProductsTableTableManager get recentProducts =>
      $$RecentProductsTableTableManager(
          _db.attachedDatabase, _db.recentProducts);
  $$CatalogSyncMetaTableTableManager get catalogSyncMeta =>
      $$CatalogSyncMetaTableTableManager(
          _db.attachedDatabase, _db.catalogSyncMeta);
}
