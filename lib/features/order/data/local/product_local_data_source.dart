import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Local persistence contract for the product catalog. Backed by the single
/// encrypted Drift database (see [ProductDriftLocalDataSource]); the legacy
/// plaintext `catalog.db` product/price/stock/FTS implementation was retired in
/// the T4 cutover.
abstract interface class ProductLocalDataSource {
  /// Returns up to `pageSize + 1` rows so the caller can detect "has more"
  /// without a separate COUNT query.
  Future<List<ProductModel>> browse({
    required int page,
    required int pageSize,
    String query,
    ProductFilter filter,
  });

  /// Exact number of products matching [query] + [filter] — powers the live
  /// "Showing N products" counter without paging through the whole result set.
  Future<int> count({
    String query,
    ProductFilter filter,
  });

  Future<ProductModel?> getById(String id);
  Future<ProductModel?> getByBarcode(String barcode);
  Future<List<String>> fetchBrands();

  /// One representative row per distinct [ProductModel.code] sharing [familyId].
  Future<List<ProductModel>> getVariantsByFamily(String familyId);

  /// Every warehouse row sharing [code].
  Future<List<ProductModel>> getRowsByCode(String code);

  Future<void> toggleFavorite(String productId);
  Future<List<ProductModel>> fetchFavorites();
  Future<List<ProductModel>> fetchRecent();
  Future<void> recordViewed(String productId);

  Future<List<CategoryModel>> fetchCategories();
  Future<void> upsertCategories(List<CategoryModel> categories);

  /// Deletes every category whose id is **not** in [keepIds].
  ///
  /// Categories have no tombstone in the sync feed — [markDeleted] covers
  /// products only — so a category that disappears upstream would otherwise
  /// linger locally forever. That is survivable right up until the products
  /// that referenced it are re-pointed somewhere else: `categoriesWithProducts`
  /// is a join, so a table full of orphaned ids joins to nothing and the
  /// guided flow renders "No product categories available" on a device that
  /// just successfully synced thousands of products.
  ///
  /// Implementations MUST treat an empty [keepIds] as a no-op. A category
  /// fetch that fails and returns `[]` must never be allowed to wipe the
  /// table.
  Future<void> pruneCategoriesNotIn(List<String> keepIds);

  /// Batched, transactional upsert into the product/price/stock tables.
  Future<void> upsertProducts(List<ProductModel> products);
  Future<void> markDeleted(List<String> ids);

  Future<DateTime?> getLastSyncedAt(String entity);
  Future<void> setLastSyncedAt(String entity, DateTime at);
}
