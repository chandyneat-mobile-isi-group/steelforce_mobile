import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Drives the guided material configurator one level at a time.
///
/// Every method here answers exactly one question the rep is currently being
/// asked — "which categories?", "what comes next for Profile Roofing?", "which
/// gauges exist for CAP 980 in PALM 100PPGL?" — and never more. There is
/// deliberately no "give me the whole tree" method: that would be the same
/// unbounded download this flow exists to avoid. The live master is 13,499
/// materials; nobody finds a roofing sheet by paging 6,750 pages.
///
/// The *hierarchy* (which steps, in which order, under which business label) is
/// server-owned and arrives as configuration, so merchandising can reorder or
/// relabel a category with no app release. The *values* at each level are
/// resolved against the same filter the terminal read uses, which is what makes
/// the flow dead-end free — an option that matches nothing is never returned,
/// and a count never promises twelve and delivers nine.
///
/// Two implementations satisfy this, chosen at registration:
///
///  * the platform's material selection API, the primary path; and
///  * the device's local Drift catalog, which keeps the finder working with no
///    connectivity.
///
/// They resolve the same [FilterSelection] through their own translation, so
/// neither can silently narrow differently from the other.
abstract interface class ProductFilterRepository {
  /// Top-level categories that open the flow, with how many live materials sit
  /// behind each. Nothing else is loaded with them.
  ///
  /// Callers must offer only [MaterialCategory.isOfferable] entries: a category
  /// with no published hierarchy dead-ends, and offering a tile that goes
  /// nowhere is the same defect as offering an option that matches nothing.
  ResultFuture<List<MaterialCategory>> getFilterCategories();

  /// The filter hierarchy published for [categoryCode]. Categories with no
  /// published hierarchy resolve to a derived one where the data supports it,
  /// and to [CategoryFilterSchema.flat] where it does not — the rep is never
  /// blocked, only less guided.
  ResultFuture<CategoryFilterSchema> getFilterSchema(String categoryCode);

  /// Distinct options for exactly [step], narrowed by every answer already in
  /// [selection]. Options that match zero materials are never returned, which
  /// is what makes the flow dead-end free.
  ///
  /// The step being resolved is excluded from its own narrowing, so a rep
  /// revisiting an answered step sees every alternative rather than only the
  /// one they already picked.
  ResultFuture<List<FilterOption>> getStepOptions({
    required CategoryFilterSchema schema,
    required FilterStep step,
    required FilterSelection selection,
  });

  /// The stock locations that can supply what [selection] matched.
  ///
  /// **Returns empty against the material selection API, and that is correct
  /// rather than unimplemented.** SAP's material master carries no plant
  /// column — a material is not "at" a plant, and where it is stocked is a
  /// separate per-material question. Publishing a location facet would mean
  /// returning match counts nothing can honestly compute, so the API path
  /// answers with no options and the chip row renders nothing. The local
  /// catalog, whose rows *are* per-warehouse, still answers properly.
  ResultFuture<List<FilterOption>> getStockLocationOptions({
    required String? categoryId,
    required FilterSelection selection,
  });

  /// The terminal read: the materials matching a bounded selection.
  ///
  /// **Bounded means at least one answered step, or a [search] of two
  /// characters or more.** A [categoryCode] alone does not count — the largest
  /// category holds 1,549 materials, which is the unbounded read wearing a
  /// filter. Callers prevent the unbounded case rather than catching it; the
  /// server rejects it outright, and that rejection should never reach a rep
  /// as an error dialog.
  /// [sortBy], [availableOnly] and [warehouseCode] are refinements of the
  /// result set rather than answers about the article, so they never invalidate
  /// an answered step. They are honoured by whichever implementation can:
  /// the local catalog applies all three, and the selection API applies none —
  /// it exposes no sort parameter, no plant column, and already excludes
  /// blocked materials on every order-capture path.
  ResultFuture<PagedResult<Product>> getMaterials({
    required String? categoryCode,
    required FilterSelection selection,
    required int page,
    required int pageSize,
    String search = '',
    ProductSortBy sortBy = ProductSortBy.relevance,
    bool availableOnly = false,
    String? warehouseCode,
  });
}
