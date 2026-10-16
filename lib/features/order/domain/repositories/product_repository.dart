import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Hides whether a product read comes from the local database or (via the
/// sync engine, never directly) from SAP — every method here only ever
/// touches the local store, which is why they're all instant and work
/// fully offline.
abstract interface class ProductRepository {
  /// Text search (FTS, code/name/barcode/sku/brand) combined with [filter]
  /// (category/brand/warehouse/availability) and pagination.
  ResultFuture<PagedResult<Product>> searchProducts({
    required int page,
    required int pageSize,
    required String query,
    ProductFilter filter = const ProductFilter(),
  });

  /// Same paging/filtering as [searchProducts] with an empty query — kept as
  /// its own method to match the browse-without-searching entry point.
  ResultFuture<PagedResult<Product>> getProducts({
    required int page,
    required int pageSize,
    ProductFilter filter = const ProductFilter(),
  });

  ResultFuture<PagedResult<Product>> getProductsByCategory({
    required String categoryId,
    required int page,
    required int pageSize,
  });

  /// Exact count of products matching [query] + [filter], independent of
  /// paging — powers the live "Showing N products" filter counter.
  ResultFuture<int> countProducts({
    String query = '',
    ProductFilter filter = const ProductFilter(),
  });

  /// All sibling size/grade variants sharing a product family (e.g. every
  /// diameter of "SD390 Rebar"), one representative row per distinct [Product.code].
  ResultFuture<List<Product>> getProductVariants(String familyId);

  /// Every warehouse row for the same [Product.code] — how much of this
  /// exact SKU sits in each plant/warehouse.
  ResultFuture<List<Product>> getWarehouseStock(String code);

  ResultFuture<Product> getProduct(String id);
  ResultFuture<Product> searchBarcode(String barcode);
  ResultFuture<double> getPricing(String id, PriceTier tier);
  ResultFuture<List<String>> fetchBrands();

  ResultFuture<void> toggleFavorite(String productId);
  ResultFuture<List<Product>> fetchFavorites();
  ResultFuture<List<Product>> fetchRecent();
  ResultFuture<void> recordViewed(String productId);
}
