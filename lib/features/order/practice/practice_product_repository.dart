import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';

/// The catalog during practice: every read is the real one — the catalog is
/// master data, and practising against it is the point — but the two writes a
/// screen can make while browsing (favourite toggled, product viewed) stay in
/// memory, so a lesson leaves no trace in the rep's favourites or recents.
/// Once [PracticeWorld.isClosed] every call goes to [_real].
class PracticeProductRepository implements ProductRepository {
  PracticeProductRepository({
    required ProductRepository real,
    required PracticeWorld world,
  })  : _real = real,
        _world = world;

  final ProductRepository _real;
  final PracticeWorld _world;

  /// Favourites flipped during practice. Read back by nobody but the screen
  /// that flipped them, which already holds the new state.
  final Set<String> _toggled = {};

  @override
  ResultFuture<void> toggleFavorite(String productId) async {
    if (_world.isClosed) return _real.toggleFavorite(productId);
    if (!_toggled.add(productId)) _toggled.remove(productId);
    return const Success(null);
  }

  @override
  ResultFuture<void> recordViewed(String productId) async {
    if (_world.isClosed) return _real.recordViewed(productId);
    return const Success(null);
  }

  // ── Reads: always the real catalog ──────────────────────────────────

  @override
  ResultFuture<PagedResult<Product>> searchProducts({
    required int page,
    required int pageSize,
    required String query,
    ProductFilter filter = const ProductFilter(),
  }) =>
      _real.searchProducts(
          page: page, pageSize: pageSize, query: query, filter: filter);

  @override
  ResultFuture<PagedResult<Product>> getProducts({
    required int page,
    required int pageSize,
    ProductFilter filter = const ProductFilter(),
  }) =>
      _real.getProducts(page: page, pageSize: pageSize, filter: filter);

  @override
  ResultFuture<PagedResult<Product>> getProductsByCategory({
    required String categoryId,
    required int page,
    required int pageSize,
  }) =>
      _real.getProductsByCategory(
          categoryId: categoryId, page: page, pageSize: pageSize);

  @override
  ResultFuture<int> countProducts({
    String query = '',
    ProductFilter filter = const ProductFilter(),
  }) =>
      _real.countProducts(query: query, filter: filter);

  @override
  ResultFuture<List<Product>> getProductVariants(String familyId) =>
      _real.getProductVariants(familyId);

  @override
  ResultFuture<List<Product>> getWarehouseStock(String code) =>
      _real.getWarehouseStock(code);

  @override
  ResultFuture<Product> getProduct(String id) => _real.getProduct(id);

  @override
  ResultFuture<Product> searchBarcode(String barcode) =>
      _real.searchBarcode(barcode);

  @override
  ResultFuture<double> getPricing(String id, PriceTier tier) =>
      _real.getPricing(id, tier);

  @override
  ResultFuture<List<String>> fetchBrands() => _real.fetchBrands();

  @override
  ResultFuture<List<Product>> fetchFavorites() => _real.fetchFavorites();

  @override
  ResultFuture<List<Product>> fetchRecent() => _real.fetchRecent();
}
