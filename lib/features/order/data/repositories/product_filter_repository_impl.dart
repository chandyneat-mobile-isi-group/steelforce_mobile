import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/product_filter_local_data_source.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/data/mock/isi_filter_schema_data.dart';
import 'package:steelforce/features/order/data/models/category_filter_schema_model.dart';
import 'package:steelforce/features/order/data/remote/product_filter_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';

/// The guided configurator over the device's own catalog — the offline twin of
/// [ApiProductFilterRepositoryImpl].
///
/// Joins the two halves of the flow: the published hierarchy (remote, cached
/// configuration) and the locally synced values that populate it. The rep can
/// walk five levels of the catalog having transferred nothing but a few
/// kilobytes of option labels, with the radio off the whole way.
///
/// Note the deliberate asymmetry with the API path: here a `products` row is a
/// SKU *at one warehouse*, so [getStockLocationOptions] genuinely has something
/// to group on and answers properly. The material master behind the API does
/// not, and answers with nothing. Both are correct for their own data.
class ProductFilterRepositoryImpl implements ProductFilterRepository {
  ProductFilterRepositoryImpl({
    required ProductFilterRemoteDataSource remote,
    required ProductFilterLocalDataSource local,
    ProductLocalDataSource? products,
  })  : _remote = remote,
        _local = local,
        _products = products;

  final ProductFilterRemoteDataSource _remote;
  final ProductFilterLocalDataSource _local;
  final ProductLocalDataSource? _products;

  Map<String, CategoryFilterSchemaModel>? _schemasById;

  @override
  ResultFuture<List<MaterialCategory>> getFilterCategories() async {
    try {
      final rows = await _local.categoriesWithProducts();
      return Success([
        for (final c in rows)
          MaterialCategory(
            code: c.id,
            name: c.name,
            // The local query already filters to categories holding at least
            // one live product, so the exact figure is not carried. Zero would
            // read as "empty" and suppress the tile, so the count is reported
            // as unknown-but-nonzero rather than fabricated.
            materialCount: 1,
            hasPublishedSchema: true,
            icon: c.icon ?? c.code,
          ),
      ]);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<CategoryFilterSchema> getFilterSchema(
      String categoryCode) async {
    try {
      final published = (await _loadSchemas())[categoryCode];
      if (published != null) return Success(published.toEntity());

      // No bespoke hierarchy for this category — fall back to the generic one
      // the backend also publishes, rather than dropping the rep into an
      // unfiltered catalog. Its steps are all optional and the flow skips any
      // that resolve to nothing, so it adapts to whatever the category has.
      final generic = CategoryFilterSchemaModel.fromJson(
        IsiFilterSchemaData.genericSchemaFor(
          categoryId: categoryCode,
          categoryName: '',
        ),
      );
      return Success(generic.toEntity());
    } on ServerException catch (e) {
      return Failed(ServerFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<FilterOption>> getStepOptions({
    required CategoryFilterSchema schema,
    required FilterStep step,
    required FilterSelection selection,
  }) async {
    final facet = step.attribute.localFacet;
    if (facet == null) {
      // A server-published step naming a SAP classification the local catalog
      // has no column for. Answering with no options makes the flow skip it,
      // which is the same thing it does for any step with nothing to ask —
      // and far better than grouping on the wrong column offline.
      return const Success(<FilterOption>[]);
    }
    try {
      final values = await _local.facetValues(
        facet: facet,
        filter: selection.toProductFilter(schema.categoryId),
      );
      return Success(values
          .map((v) => FilterOption(
                value: v.value,
                label: _label(step, v.label),
                matchCount: v.matchCount,
              ))
          .toList());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<FilterOption>> getStockLocationOptions({
    required String? categoryId,
    required FilterSelection selection,
  }) async {
    try {
      // Deliberately resolved against the selection *without* a warehouse
      // narrowing: the options have to keep showing every location the rep
      // could switch to, not just the one they are already on.
      final values = await _local.facetValues(
        facet: 'warehouse',
        filter: selection.toProductFilter(categoryId),
      );
      return Success(values
          .map((v) => FilterOption(
                value: v.value,
                label: v.label,
                matchCount: v.matchCount,
              ))
          .toList());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<PagedResult<Product>> getMaterials({
    required String? categoryCode,
    required FilterSelection selection,
    required int page,
    required int pageSize,
    String search = '',
    ProductSortBy sortBy = ProductSortBy.relevance,
    bool availableOnly = false,
    String? warehouseCode,
  }) async {
    try {
      // The local browse is zero-based and returns `pageSize + 1` rows so the
      // caller can tell "has more" without a second COUNT. The API path is
      // one-based, so the offset is normalised here rather than leaking two
      // paging conventions into the bloc.
      final zeroBased = page <= 0 ? 0 : page - 1;
      final products = _products;
      if (products == null) {
        return const Failed(CacheFailure(
          message: 'The local material catalog is not available.',
        ));
      }
      final rows = await products.browse(
        page: zeroBased,
        pageSize: pageSize,
        query: search.trim(),
        filter: selection.toProductFilter(
          categoryCode,
          sortBy: sortBy,
          availableOnly: availableOnly,
          warehouseCode: warehouseCode,
        ),
      );
      final hasMore = rows.length > pageSize;
      return Success(PagedResult<Product>(
        items: hasMore ? rows.take(pageSize).toList() : rows,
        page: page,
        hasMore: hasMore,
      ));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  Future<Map<String, CategoryFilterSchemaModel>> _loadSchemas() async {
    final cached = _schemasById;
    if (cached != null) return cached;
    final schemas = await _remote.fetchFilterSchemas();
    return _schemasById = {for (final s in schemas) s.categoryId: s};
  }

  /// Applies the step's published notation to a raw catalog value: SQLite hands
  /// back "0.3" and "12.0" where the sales sheet says "0.30 mm" and "12 mm".
  static String _label(FilterStep step, String raw) {
    if (!step.attribute.isNumeric) return raw;
    final parsed = double.tryParse(raw);
    if (parsed == null) return raw;
    final decimals = step.decimals;
    final formatted = decimals != null
        ? parsed.toStringAsFixed(decimals)
        : (parsed == parsed.roundToDouble()
            ? parsed.toStringAsFixed(0)
            : parsed.toString());
    return step.unitSuffix == null
        ? formatted
        : '$formatted ${step.unitSuffix}';
  }
}
