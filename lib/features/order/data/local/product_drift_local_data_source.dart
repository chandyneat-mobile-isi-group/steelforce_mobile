import 'package:drift/drift.dart' show QueryRow;
import 'package:steelforce/core/database/drift/daos/catalog_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/order/data/local/product_drift_mappers.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// [ProductLocalDataSource] backed by the single encrypted Drift database
/// (T4 cutover) via [CatalogDao]. The joined product SELECTs return rows whose
/// column aliases match [ProductModel.fromRow] exactly, so mapping is a direct
/// `fromRow(row.data)`. Exceptions are normalised to [CacheException].
class ProductDriftLocalDataSource implements ProductLocalDataSource {
  const ProductDriftLocalDataSource(this._dao);

  final CatalogDao _dao;

  ProductModel _map(QueryRow row) => ProductModel.fromRow(row.data);

  @override
  Future<List<ProductModel>> browse({
    required int page,
    required int pageSize,
    String query = '',
    ProductFilter filter = const ProductFilter(),
  }) async {
    try {
      await MockLatency.tick(); // preserve the "slow catalog API" feel
      final rows = await _dao.browseProducts(
        filter.toQuery(query: query, page: page, pageSize: pageSize),
      );
      return rows.map(_map).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to browse products: $e');
    }
  }

  @override
  Future<int> count({
    String query = '',
    ProductFilter filter = const ProductFilter(),
  }) async {
    try {
      return await _dao.countProducts(
        filter.toQuery(query: query, page: 0, pageSize: 0),
      );
    } catch (e) {
      throw CacheException(message: 'Failed to count products: $e');
    }
  }

  @override
  Future<ProductModel?> getById(String id) async {
    try {
      final row = await _dao.productById(id);
      return row == null ? null : _map(row);
    } catch (e) {
      throw CacheException(message: 'Failed to load product $id: $e');
    }
  }

  @override
  Future<ProductModel?> getByBarcode(String barcode) async {
    try {
      final row = await _dao.productByBarcode(barcode);
      return row == null ? null : _map(row);
    } catch (e) {
      throw CacheException(message: 'Failed to look up barcode $barcode: $e');
    }
  }

  @override
  Future<List<ProductModel>> getVariantsByFamily(String familyId) async {
    try {
      final rows = await _dao.variantRowsByFamily(familyId);
      return rows.map(_map).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load product variants: $e');
    }
  }

  @override
  Future<List<ProductModel>> getRowsByCode(String code) async {
    try {
      final rows = await _dao.rowsByCode(code);
      return rows.map(_map).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load warehouse stock: $e');
    }
  }

  @override
  Future<List<String>> fetchBrands() async {
    try {
      return await _dao.distinctBrands();
    } catch (e) {
      throw CacheException(message: 'Failed to load brands: $e');
    }
  }

  @override
  Future<void> toggleFavorite(String productId) async {
    try {
      await _dao.toggleFavorite(productId);
    } catch (e) {
      throw CacheException(message: 'Failed to toggle favorite: $e');
    }
  }

  @override
  Future<List<ProductModel>> fetchFavorites() async {
    try {
      final rows = await _dao.favoriteProductRows();
      return rows.map(_map).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load favorites: $e');
    }
  }

  @override
  Future<List<ProductModel>> fetchRecent() async {
    try {
      final rows = await _dao.recentProductRows();
      return rows.map(_map).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load recent products: $e');
    }
  }

  @override
  Future<void> recordViewed(String productId) async {
    try {
      await _dao.recordViewed(productId);
    } catch (e) {
      throw CacheException(message: 'Failed to record viewed product: $e');
    }
  }

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      await MockLatency.tick(); // preserve the "slow categories API" feel
      final rows = await _dao.fetchCategories();
      return rows.map((c) => c.toModel()).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load categories: $e');
    }
  }

  @override
  Future<void> upsertCategories(List<CategoryModel> categories) async {
    try {
      await _dao
          .upsertCategories(categories.map((c) => c.toCompanion()).toList());
    } catch (e) {
      throw CacheException(message: 'Failed to save categories: $e');
    }
  }

  @override
  Future<void> pruneCategoriesNotIn(List<String> keepIds) async {
    // Guard here as well as in the DAO: this is the call that can empty the
    // category table, and it is reached from a network-fed list.
    if (keepIds.isEmpty) return;
    try {
      await _dao.pruneCategoriesNotIn(keepIds);
    } catch (e) {
      throw CacheException(message: 'Failed to prune stale categories: $e');
    }
  }

  @override
  Future<void> upsertProducts(List<ProductModel> products) async {
    try {
      await _dao.upsertCatalog(
        productRows: products.map((p) => p.toProductCompanion()).toList(),
        priceRows: products.map((p) => p.toPriceCompanion()).toList(),
        stockRows: products.map((p) => p.toStockCompanion()).toList(),
      );
    } catch (e) {
      throw CacheException(message: 'Failed to save synced products: $e');
    }
  }

  @override
  Future<void> markDeleted(List<String> ids) async {
    try {
      await _dao.markDeleted(ids);
    } catch (e) {
      throw CacheException(message: 'Failed to apply deletions: $e');
    }
  }

  @override
  Future<DateTime?> getLastSyncedAt(String entity) async {
    try {
      return await _dao.getLastSyncedAt(entity);
    } catch (e) {
      throw CacheException(message: 'Failed to read sync metadata: $e');
    }
  }

  @override
  Future<void> setLastSyncedAt(String entity, DateTime at) async {
    try {
      await _dao.setLastSyncedAt(entity, at);
    } catch (e) {
      throw CacheException(message: 'Failed to write sync metadata: $e');
    }
  }
}
