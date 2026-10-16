import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';

/// Every read here is local-only — the sync engine ([SyncRepositoryImpl]) is
/// the sole path data takes from remote into the local tables this queries.
class ProductRepositoryImpl implements ProductRepository {
  const ProductRepositoryImpl(this._local);
  final ProductLocalDataSource _local;

  @override
  ResultFuture<PagedResult<Product>> searchProducts({
    required int page,
    required int pageSize,
    required String query,
    ProductFilter filter = const ProductFilter(),
  }) =>
      _browse(page: page, pageSize: pageSize, query: query, filter: filter);

  @override
  ResultFuture<PagedResult<Product>> getProducts({
    required int page,
    required int pageSize,
    ProductFilter filter = const ProductFilter(),
  }) =>
      _browse(page: page, pageSize: pageSize, query: '', filter: filter);

  @override
  ResultFuture<PagedResult<Product>> getProductsByCategory({
    required String categoryId,
    required int page,
    required int pageSize,
  }) =>
      _browse(
          page: page,
          pageSize: pageSize,
          filter: ProductFilter(categoryId: categoryId));

  Future<Result<PagedResult<Product>>> _browse({
    required int page,
    required int pageSize,
    String query = '',
    ProductFilter filter = const ProductFilter(),
  }) async {
    try {
      final rows = await _local.browse(
          page: page, pageSize: pageSize, query: query, filter: filter);
      final hasMore = rows.length > pageSize;
      final items = hasMore ? rows.sublist(0, pageSize) : rows;
      return Success(
          PagedResult<Product>(items: items, page: page, hasMore: hasMore));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<int> countProducts({
    String query = '',
    ProductFilter filter = const ProductFilter(),
  }) async {
    try {
      return Success(await _local.count(query: query, filter: filter));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Product>> getProductVariants(String familyId) async {
    try {
      return Success(await _local.getVariantsByFamily(familyId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Product>> getWarehouseStock(String code) async {
    try {
      return Success(await _local.getRowsByCode(code));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Product> getProduct(String id) async {
    try {
      final product = await _local.getById(id);
      if (product == null) {
        return const Failed(CacheFailure(message: 'Product not found.'));
      }
      return Success(product);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Product> searchBarcode(String barcode) async {
    try {
      final product = await _local.getByBarcode(barcode);
      if (product == null) {
        return const Failed(
            CacheFailure(message: 'No product matches that barcode.'));
      }
      return Success(product);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<double> getPricing(String id, PriceTier tier) async {
    try {
      final product = await _local.getById(id);
      if (product == null) {
        return const Failed(CacheFailure(message: 'Product not found.'));
      }
      return Success(product.pricing.priceFor(tier));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<String>> fetchBrands() async {
    try {
      return Success(await _local.fetchBrands());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> toggleFavorite(String productId) async {
    try {
      await _local.toggleFavorite(productId);
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Product>> fetchFavorites() async {
    try {
      return Success(await _local.fetchFavorites());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Product>> fetchRecent() async {
    try {
      return Success(await _local.fetchRecent());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> recordViewed(String productId) async {
    try {
      await _local.recordViewed(productId);
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }
}
