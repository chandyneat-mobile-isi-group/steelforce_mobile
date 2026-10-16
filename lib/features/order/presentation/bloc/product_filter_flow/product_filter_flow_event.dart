import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

sealed class ProductFilterFlowEvent extends Equatable {
  const ProductFilterFlowEvent();
  @override
  List<Object?> get props => [];
}

/// Opens the configurator. Loads categories and nothing else — the entire
/// point of the redesign is that entering here costs one small query.
final class FilterFlowStarted extends ProductFilterFlowEvent {
  const FilterFlowStarted();
}

final class FilterCategorySelected extends ProductFilterFlowEvent {
  const FilterCategorySelected(this.category);
  final MaterialCategory category;
  @override
  List<Object?> get props => [category];
}

/// Answers the step currently being asked. The bloc knows which one that is,
/// so callers can't answer out of order.
final class FilterStepAnswered extends ProductFilterFlowEvent {
  const FilterStepAnswered({required this.stepKey, required this.option});
  final String stepKey;
  final FilterOption option;
  @override
  List<Object?> get props => [stepKey, option];
}

/// Removes one answer and everything downstream of it — the summary bar's
/// per-chip clear.
final class FilterStepCleared extends ProductFilterFlowEvent {
  const FilterStepCleared(this.stepKey);
  final String stepKey;
  @override
  List<Object?> get props => [stepKey];
}

/// One step backwards: drops the most recent answer, or returns to the
/// category list when there is none left.
final class FilterFlowBackRequested extends ProductFilterFlowEvent {
  const FilterFlowBackRequested();
}

/// Back to the category list, discarding the current category's answers.
final class FilterFlowReset extends ProductFilterFlowEvent {
  const FilterFlowReset();
}

/// Next page of the product result list.
final class FilterProductsLoadMoreRequested extends ProductFilterFlowEvent {
  const FilterProductsLoadMoreRequested();
}

/// Free-text search, available at every stage.
///
/// A rep who already knows the material code types it and gets products
/// immediately; a rep mid-hierarchy gets their current narrowing *plus* the
/// text. Both go through the same query, so the two never disagree.
final class FilterProductSearchChanged extends ProductFilterFlowEvent {
  const FilterProductSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

/// Result-set preferences from the Filter sheet. These re-run the product
/// query without touching the answered steps.
final class FilterPreferencesChanged extends ProductFilterFlowEvent {
  const FilterPreferencesChanged({this.sortBy, this.availableOnly});
  final ProductSortBy? sortBy;
  final bool? availableOnly;
  @override
  List<Object?> get props => [sortBy, availableOnly];
}

/// "Find New Product": clears the category, the answered steps, the search and
/// the results, and returns to category selection. The cart is untouched —
/// that is the entire point of the action.
final class FindNewProductRequested extends ProductFilterFlowEvent {
  const FindNewProductRequested();
}

/// Re-runs the current product query (pull-to-refresh, or after a sync).
final class FilterProductsRefreshed extends ProductFilterFlowEvent {
  const FilterProductsRefreshed();
}

/// Narrows the matched SKUs to one stock location, or back to all of them with
/// a null [warehouseCode].
///
/// Deliberately *not* a [FilterStepAnswered]. A step answer invalidates every
/// answer below it, which is right for "thickness changed, so length must be
/// re-asked" and wrong here: location is chosen after the SKUs are on screen
/// and changes only which of them are listed. Sending it as its own event is
/// what keeps the guided hierarchy untouched.
final class FilterStockLocationChanged extends ProductFilterFlowEvent {
  const FilterStockLocationChanged(this.warehouseCode);
  final String? warehouseCode;
  @override
  List<Object?> get props => [warehouseCode];
}

/// Asks SAP whether one material may actually be sold.
///
/// Fired automatically when the rep answers the SKU step, which is the moment
/// they stop narrowing and name a material. Exposed as an event as well so a
/// card can retry a check that failed, without the widget needing to know that
/// a live ERP round trip sits behind it.
///
/// [material] is the SAP material number, not the platform row id.
final class FilterMaterialAvailabilityRequested extends ProductFilterFlowEvent {
  const FilterMaterialAvailabilityRequested(this.material);
  final String material;
  @override
  List<Object?> get props => [material];
}

/// Selecting a specific SKU from search results to display its full ProductCard.
/// Pass `null` to collapse or clear the selection.
final class FilterProductSkuSelected extends ProductFilterFlowEvent {
  const FilterProductSkuSelected(this.sku);
  final String? sku;
  @override
  List<Object?> get props => [sku];
}
