import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/models/category_filter_schema_model.dart';
import 'package:steelforce/features/order/data/models/material_api_mapper.dart';
import 'package:steelforce/features/order/data/remote/material_selection_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';

/// The guided finder over the platform's material selection API.
///
/// The primary path. Its offline twin, `ProductFilterRepositoryImpl`, resolves
/// the same [FilterSelection] against the device's Drift catalog; both are
/// registered behind the same interface so the bloc above has one call site and
/// never learns which one answered.
///
/// Two things this implementation is careful about, both of them lessons the
/// backend documented rather than guesses:
///
///  * **The schema is configuration, not catalogue data.** Around 9.5 KB for
///    every published hierarchy, changing only when merchandising edits it. It
///    is fetched once and held for the process lifetime; re-reading it per
///    category would turn a free lookup into a round trip per tap.
///  * **The bounded rule is prevented, not caught.** `getMaterials` returns an
///    empty page for a selection that narrows nothing rather than letting the
///    server answer 400. That refusal is correct on the wire and useless on a
///    screen — "there are no materials" and "narrow it down first" are very
///    different claims, and the flow's own gate should mean neither is ever
///    needed.
class ApiProductFilterRepositoryImpl implements ProductFilterRepository {
  ApiProductFilterRepositoryImpl(this._remote);

  final MaterialSelectionRemoteDataSource _remote;

  Map<String, CategoryFilterSchemaModel>? _schemasByCode;

  @override
  ResultFuture<List<MaterialCategory>> getFilterCategories() async {
    try {
      final rows = await _remote.fetchCategories();
      final categories = rows.map(MaterialApiMapper.categoryFrom).toList();
      // Filtered here rather than in the widget so every caller of this
      // repository gets the same set. A named category without a published
      // hierarchy is derived by the API; only one holding no live materials
      // has nowhere to go.
      return Success(categories.where((c) => c.isOfferable).toList());
    } on ApiException catch (e) {
      return Failed(_failure(e));
    } on ServerException catch (e) {
      return Failed(ServerFailure(message: e.message));
    }
  }

  @override
  ResultFuture<CategoryFilterSchema> getFilterSchema(
      String categoryCode) async {
    try {
      final published = (await _loadSchemas())[categoryCode];
      if (published != null) return Success(published.toEntity());

      // Not in the bulk read — ask for this one by name, which is what makes
      // the server derive a hierarchy from what the category's data actually
      // holds. Only 12 of 49 categories are merchandised; the rest reach the
      // rep this way rather than not at all.
      final derived = await _remote.fetchSchemas(categoryCode: categoryCode);
      if (derived.isNotEmpty) {
        final schema = derived.first;
        _schemasByCode?[schema.categoryId] = schema;
        return Success(schema.toEntity());
      }

      // Nothing published and nothing derivable. The flow degrades to
      // "category → search" rather than blocking the rep.
      return Success(CategoryFilterSchema.flat(
        categoryId: categoryCode,
        categoryName: '',
      ));
    } on ApiException catch (e) {
      return Failed(_failure(e));
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
    final attribute = step.attribute.wireName;
    if (attribute == null) {
      // A step naming an attribute the material master has no column for. The
      // server would answer 400 `Material.UnknownFilterAttribute`; answering
      // with no options instead makes the flow skip the step, which is the
      // same thing it does for a step that resolves to nothing.
      return const Success(<FilterOption>[]);
    }
    try {
      final rows = await _remote.fetchFacetOptions(
        attribute: attribute,
        selection: selection.toApiSelection(categoryCode: schema.categoryId),
      );
      return Success(rows
          .map(MaterialApiMapper.facetFrom)
          .map((o) => FilterOption(
                value: o.value,
                label: _label(step, o.label),
                matchCount: o.matchCount,
              ))
          .toList());
    } on ApiException catch (e) {
      return Failed(_failure(e));
    } on ServerException catch (e) {
      return Failed(ServerFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<FilterOption>> getStockLocationOptions({
    required String? categoryId,
    required FilterSelection selection,
  }) async {
    // Not unimplemented — unavailable, and honestly so. SAP's material master
    // carries no plant column: `GetMateByPaging` returns one row per material,
    // so there is no per-warehouse duplication to group on and no match count
    // this table could compute. Where a material is stocked is a separate live
    // per-material question, not a facet.
    //
    // Returning nothing is what the chip row is already built to handle: it
    // renders only when there is a genuine choice between locations.
    return const Success(<FilterOption>[]);
  }

  @override
  ResultFuture<PagedResult<Product>> getMaterials({
    required String? categoryCode,
    required FilterSelection selection,
    required int page,
    required int pageSize,
    String search = '',
    // Accepted and ignored, deliberately. The selection API exposes no sort
    // parameter and no plant column, and `excludeBlocked` is already true on
    // every path that leads to order capture. Silently accepting these keeps
    // one call site in the bloc; silently *applying* a page-local sort would
    // be worse than not sorting, because it would look right on page one and
    // be wrong across the rest.
    ProductSortBy sortBy = ProductSortBy.relevance,
    bool availableOnly = false,
    String? warehouseCode,
  }) async {
    final trimmed = search.trim();
    final bounded = selection.hasAnswer || trimmed.length >= 2;
    if (!bounded) {
      // The flow's own gate should make this unreachable. Kept as a floor
      // rather than an assertion because the cost of getting it wrong is a
      // 400 in front of a rep, and an empty page they never see is cheaper
      // than an error dialog they do.
      return Success(
          PagedResult<Product>(items: const [], page: page, hasMore: false));
    }

    try {
      final result = await _remote.fetchMaterials(
        selection: selection.toApiSelection(categoryCode: categoryCode),
        page: page,
        pageSize: pageSize,
        search: trimmed.isEmpty ? null : trimmed,
      );
      return Success(PagedResult<Product>(
        items: result.rows
            .map((r) =>
                MaterialApiMapper.materialFrom(r, categoryCode: categoryCode))
            .toList(),
        page: page,
        hasMore: result.hasMore,
      ));
    } on ApiException catch (e) {
      return Failed(_failure(e));
    } on ServerException catch (e) {
      return Failed(ServerFailure(message: e.message));
    }
  }

  Future<Map<String, CategoryFilterSchemaModel>> _loadSchemas() async {
    final cached = _schemasByCode;
    if (cached != null) return cached;
    final schemas = await _remote.fetchSchemas();
    return _schemasByCode = {for (final s in schemas) s.categoryId: s};
  }

  /// Applies the step's published notation to a raw facet value: the server
  /// sends `0.400` where the sales sheet says `0.40 mm`.
  ///
  /// The formatting lives with the step rather than with the value because it
  /// is per-attribute business notation, not a rendering preference — coil
  /// thickness reads `0.30`, rebar diameter reads `12`.
  static String _label(FilterStep step, String raw) {
    if (!step.attribute.isNumeric) return raw;
    // Invariant on the wire — always a decimal point, never a comma — so this
    // parses without consulting a locale.
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

  /// A 403 here means the role is missing `materials.read`, which is a
  /// permissions fix rather than anything the app can retry — so it must not
  /// be reported as a transport problem, and (per the platform's rule) must
  /// never sign the user out.
  static Failure _failure(ApiException e) => ServerFailure(
        message: e.error.message ?? 'Could not load materials.',
        statusCode: e.statusCode,
      );
}
