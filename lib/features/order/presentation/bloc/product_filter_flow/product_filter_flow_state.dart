import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/entities/filter/category_filter_schema.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Which screen of the configurator the rep is on. Derived from the state
/// rather than stored, so the two can never disagree.
enum FilterFlowStage { categories, steps, products }

enum FilterFlowStatus { initial, loading, ready, failure }

/// Lifecycle of the *product list only* — kept separate from
/// [FilterFlowStatus] so loading a page of results never makes the filter
/// summary or the answered steps flicker.
enum ProductListStatus { idle, loading, loaded, loadingMore, failure }

/// The complete guided-selection flow as one immutable value.
///
/// Every widget in the flow renders a projection of this and owns no state of
/// its own — including the "which step am I on" question, which is answered by
/// [activeStep] rather than by a PageController or a local index. That is what
/// makes back-navigation, chip removal and process death all behave the same:
/// they are each just a different [FilterSelection].
class ProductFilterFlowState extends Equatable {
  const ProductFilterFlowState({
    this.status = FilterFlowStatus.initial,
    this.errorMessage,
    this.categories = const [],
    this.category,
    this.schema,
    this.selection = const FilterSelection.empty(),
    this.skippedStepKeys = const {},
    this.activeStep,
    this.activeOptions = const [],
    this.optionsLoading = false,
    this.products = const [],
    this.productStatus = ProductListStatus.idle,
    this.page = 0,
    this.hasMore = false,
    this.query = '',
    this.sortBy = ProductSortBy.relevance,
    this.availableOnly = false,
    this.stockLocations = const [],
    this.stockLocationCode,
    this.stockLocationsLoading = false,
    this.availability = const {},
    this.selectedSku,
  });

  final FilterFlowStatus status;
  final String? errorMessage;

  final List<MaterialCategory> categories;
  final MaterialCategory? category;
  final CategoryFilterSchema? schema;

  final FilterSelection selection;

  /// Steps that resolved to zero options for the current selection and were
  /// therefore passed over. Tracked so the flow doesn't re-offer them and so
  /// "back" can step over them in the same order it stepped forward.
  final Set<String> skippedStepKeys;

  /// The step being asked right now; null once every step is answered.
  final FilterStep? activeStep;
  final List<FilterOption> activeOptions;
  final bool optionsLoading;

  final List<Product> products;
  final ProductListStatus productStatus;
  final int page;
  final bool hasMore;

  /// Free-text search. Unlike the guided steps this is available at every
  /// stage: an experienced rep who already knows the material code should not
  /// have to walk a hierarchy to reach it.
  final String query;

  /// The SKU or product id selected by the user from search results.
  /// When null, only lightweight SKU cards are rendered during search.
  /// When non-null, the full ProductCard for this selected SKU is rendered.
  final String? selectedSku;

  /// The currently selected product in search results, if any.
  Product? get selectedProduct {
    if (selectedSku == null) return null;
    for (final p in products) {
      if (p.sku == selectedSku ||
          p.id == selectedSku ||
          p.code == selectedSku ||
          p.materialCode == selectedSku) {
        return p;
      }
    }
    return null;
  }

  /// Result-set preferences set from the Filter sheet. They re-run the product
  /// query but never invalidate a [selection].
  final ProductSortBy sortBy;
  final bool availableOnly;

  /// Stock locations that can supply the currently matched SKUs, with a count
  /// each. Resolved once the flow reaches products — before that there is no
  /// meaningful set to offer.
  final List<FilterOption> stockLocations;

  /// The selected location, or null for "any". Narrows the result set to one
  /// warehouse; like [sortBy] and [availableOnly] it never invalidates an
  /// answered step, because it is a refinement of the results rather than an
  /// answer about the article.
  final String? stockLocationCode;

  final bool stockLocationsLoading;

  /// SAP's sellability verdicts, keyed by material number.
  ///
  /// Sparse on purpose. The check is a live ERP round trip, so it is spent on
  /// the one material the rep committed to at the SKU step — never on a page
  /// of cards they are only scrolling past. A material absent from this map has
  /// not been asked about, which is a different thing from having been refused,
  /// and the card renders the two differently.
  final Map<String, MaterialAvailability> availability;

  /// The verdict for [material], or null when it was never asked.
  MaterialAvailability? availabilityFor(String material) =>
      availability[material];

  /// Whether choosing a location would actually change anything. One location
  /// means every matched SKU ships from the same place, so offering the choice
  /// would be a control that does nothing.
  bool get hasStockLocationChoice => stockLocations.length > 1;

  /// A query long enough to be worth a catalog round-trip. One character
  /// matches most of the catalog, which is the unbounded read this flow exists
  /// to prevent.
  static const minQueryLength = 2;

  bool get hasSearch => query.trim().length >= minQueryLength;

  FilterFlowStage get stage {
    // An explicit search outranks the hierarchy: the rep has told us exactly
    // what they want, so show results wherever they were in the flow.
    if (hasSearch) return FilterFlowStage.products;
    if (category == null) return FilterFlowStage.categories;
    // "No active step" only means the flow is finished once we actually know
    // what the steps are. While the schema or an option list is in flight
    // there is no active step *yet*, and treating that as completion would
    // flash the product stage — and, worse, satisfy [isFilterComplete].
    if (activeStep != null || optionsLoading || schema == null) {
      return FilterFlowStage.steps;
    }
    return FilterFlowStage.products;
  }

  /// True once every required step is answered.
  bool get isFilterComplete => stage == FilterFlowStage.products;

  /// Whether the current state narrows anything at all.
  ///
  /// The client half of the server's bounded-selection rule, and the reason
  /// [isFilterComplete] is not sufficient on its own: a category with a derived
  /// or empty hierarchy is "complete" the moment it is picked, having answered
  /// nothing. Asking for its materials would be a request for 1,549 rows —
  /// exactly the unbounded read this flow exists to prevent, and exactly what
  /// the server answers `Material.SelectionNotBounded` to.
  ///
  /// A [category] deliberately does not count.
  bool get isBounded => hasSearch || selection.hasAnswer;

  /// The single condition under which the terminal material read may run.
  ///
  /// Both halves matter: bounded says the request is *allowed*, and the stage
  /// says the rep is actually looking at results rather than mid-hierarchy.
  bool get canRequestMaterials => isBounded && isFilterComplete;

  /// Why the rep cannot see materials yet, when they cannot.
  ///
  /// Surfaced as a disabled state with a reason rather than left for the server
  /// to reject: `Material.SelectionNotBounded` is a correct answer on the wire
  /// and a useless one on a screen.
  bool get needsNarrowing => isFilterComplete && !isBounded;

  /// 1-based position of the active step, for "Step 2 of 5".
  int get activeStepNumber {
    final current = activeStep;
    final steps = schema?.steps;
    if (current == null || steps == null) return 0;
    return steps.indexOf(current) + 1;
  }

  int get totalSteps => schema?.steps.length ?? 0;

  /// Whether there is anywhere to go back to from here.
  bool get canGoBack => category != null;

  ProductFilterFlowState copyWith({
    FilterFlowStatus? status,
    String? Function()? errorMessage,
    List<MaterialCategory>? categories,
    MaterialCategory? Function()? category,
    CategoryFilterSchema? Function()? schema,
    FilterSelection? selection,
    Set<String>? skippedStepKeys,
    FilterStep? Function()? activeStep,
    List<FilterOption>? activeOptions,
    bool? optionsLoading,
    List<Product>? products,
    ProductListStatus? productStatus,
    int? page,
    bool? hasMore,
    String? query,
    ProductSortBy? sortBy,
    bool? availableOnly,
    List<FilterOption>? stockLocations,
    String? Function()? stockLocationCode,
    bool? stockLocationsLoading,
    Map<String, MaterialAvailability>? availability,
    String? Function()? selectedSku,
  }) {
    return ProductFilterFlowState(
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      categories: categories ?? this.categories,
      category: category != null ? category() : this.category,
      schema: schema != null ? schema() : this.schema,
      selection: selection ?? this.selection,
      skippedStepKeys: skippedStepKeys ?? this.skippedStepKeys,
      activeStep: activeStep != null ? activeStep() : this.activeStep,
      activeOptions: activeOptions ?? this.activeOptions,
      optionsLoading: optionsLoading ?? this.optionsLoading,
      products: products ?? this.products,
      productStatus: productStatus ?? this.productStatus,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
      sortBy: sortBy ?? this.sortBy,
      availableOnly: availableOnly ?? this.availableOnly,
      stockLocations: stockLocations ?? this.stockLocations,
      stockLocationCode: stockLocationCode != null
          ? stockLocationCode()
          : this.stockLocationCode,
      stockLocationsLoading:
          stockLocationsLoading ?? this.stockLocationsLoading,
      availability: availability ?? this.availability,
      selectedSku: selectedSku != null ? selectedSku() : this.selectedSku,
    );
  }

  /// The catalog query the current state resolves to — one place, so the
  /// guided path and the direct-search path can never drift apart.
  ProductFilter get productFilter => selection.toProductFilter(
        category?.code,
        sortBy: sortBy,
        availableOnly: availableOnly,
        warehouseCode: stockLocationCode,
      );

  /// Anything the rep can clear from the Filter sheet.
  bool get hasAnyFilter =>
      category != null ||
      selection.isNotEmpty ||
      query.isNotEmpty ||
      availableOnly ||
      stockLocationCode != null ||
      sortBy != ProductSortBy.relevance;

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        categories,
        category,
        schema,
        selection,
        skippedStepKeys,
        activeStep,
        activeOptions,
        optionsLoading,
        products,
        productStatus,
        page,
        hasMore,
        query,
        sortBy,
        availableOnly,
        stockLocations,
        stockLocationCode,
        stockLocationsLoading,
        availability,
        selectedSku,
      ];
}
