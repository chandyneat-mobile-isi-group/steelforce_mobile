import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/promotion/promotion_cubit.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/promotion_detail_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/manual_price_input_sheet.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_summary_bar.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/category_selector.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/dynamic_filter_section.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/empty_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_chip_bar.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_options_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/find_new_product_button.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/loading_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_family_selector.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_card.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_grid.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_search_bar.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/sku_search_card.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/stock_location_chips.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The product finder, assembled from the flow's reusable parts.
///
/// Layout is fixed and always in this order — search + filter, active filter
/// chips, then whichever stage the flow is on, then the cart summary. The
/// header never disappears: an experienced rep types a material code from the
/// category screen and gets products; a new rep walks the hierarchy. Both are
/// first-class, neither hides the other's entry point.
///
/// One widget serves both hosts (the standalone finder screen and the
/// quotation builder's product section) because it renders nothing but a
/// projection of [ProductFilterFlowState] plus the live [CartCubit], and
/// reports intent back as events. Set [sticky] when it owns the viewport.
class GuidedProductFilterView extends StatefulWidget {
  const GuidedProductFilterView({
    super.key,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onQuantityChanged,
    required this.quantityFor,
    this.lineTotalFor,
    this.onCustomize,
    this.onProductTap,
    this.onVoiceSearch,
    this.onImageSearch,
    this.onCartTap,
    this.sticky = true,
    this.depotId,
    this.leadId,
    this.onInputPrice,
    this.hostManualPriceFor,
  });

  final Set<String> favoriteIds;
  final ValueChanged<Product> onToggleFavorite;

  /// The single write path into the quotation. Zero means "remove this line".
  final void Function(Product product, int quantity) onQuantityChanged;

  /// Current cart quantity for a product, resolved by the host from
  /// [CartCubit] so this view never owns cart state.
  final int Function(Product product) quantityFor;

  final String Function(Product product, int quantity)? lineTotalFor;

  final ValueChanged<Product>? onCustomize;
  final ValueChanged<Product>? onProductTap;

  /// Alternative ways to produce the query. They resolve to text and feed the
  /// same search field, so voice and photo lookup stay first-class.
  final Future<String?> Function()? onVoiceSearch;
  final Future<String?> Function()? onImageSearch;

  final VoidCallback? onCartTap;

  final bool sticky;

  final String? depotId;
  final String? leadId;
  final Future<void> Function(Product product)? onInputPrice;
  final double? Function(Product product)? hostManualPriceFor;

  @override
  State<GuidedProductFilterView> createState() =>
      _GuidedProductFilterViewState();
}

class _GuidedProductFilterViewState extends State<GuidedProductFilterView> {
  /// The text field's own editing buffer, not flow state. The query that
  /// actually filters lives in [ProductFilterFlowState.query].
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ProductFilterFlowBloc get _bloc => context.read<ProductFilterFlowBloc>();

  Future<void> _applyResolvedQuery(Future<String?> Function() resolve) async {
    final query = await resolve();
    if (query == null || query.trim().isEmpty || !mounted) return;
    _searchController.text = query;
    _bloc.add(FilterProductSearchChanged(query));
  }

  Future<void> _openFilterSheet(ProductFilterFlowState state) async {
    final result = await showFilterOptionsSheet(
      context: context,
      sortBy: state.sortBy,
      availableOnly: state.availableOnly,
      selection: state.selection,
      categoryLabel: context.localizedOrNull(state.category?.name),
    );
    if (result == null || !mounted) return;

    if (result.clearAll) {
      _searchController.clear();
      _bloc.add(const FilterFlowReset());
      return;
    }
    _bloc.add(FilterPreferencesChanged(
      sortBy: result.sortBy,
      availableOnly: result.availableOnly,
    ));
    // Each cleared step is dispatched on its own so the bloc applies its own
    // dependency rules to every one of them.
    for (final stepKey in result.clearedStepKeys) {
      _bloc.add(FilterStepCleared(stepKey));
    }
  }

  void _findNewProduct() {
    _searchController.clear();
    _bloc.add(const FindNewProductRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductFilterFlowBloc, ProductFilterFlowState>(
      builder: (context, state) {
        final header = _Header(
          state: state,
          searchController: _searchController,
          onSearchChanged: (value) =>
              _bloc.add(FilterProductSearchChanged(value)),
          onFilterTap: () => _openFilterSheet(state),
          onVoiceTap: widget.onVoiceSearch == null
              ? null
              : () => _applyResolvedQuery(widget.onVoiceSearch!),
          onImageTap: widget.onImageSearch == null
              ? null
              : () => _applyResolvedQuery(widget.onImageSearch!),
          onClearStep: (key) => _bloc.add(FilterStepCleared(key)),
          onClearCategory: () => _bloc.add(const FilterFlowReset()),
          onBack: () => _bloc.add(const FilterFlowBackRequested()),
        );

        final content = _StageContent(
          state: state,
          favoriteIds: widget.favoriteIds,
          quantityFor: widget.quantityFor,
          lineTotalFor: widget.lineTotalFor,
          onQuantityChanged: widget.onQuantityChanged,
          onToggleFavorite: widget.onToggleFavorite,
          onCustomize: widget.onCustomize,
          onProductTap: widget.onProductTap,
          onFindNewProduct: _findNewProduct,
          depotId: widget.depotId,
          leadId: widget.leadId,
          onInputPrice: widget.onInputPrice,
          hostManualPriceFor: widget.hostManualPriceFor,
        );

        final footer = _CartFooter(
          onTap: widget.onCartTap,
          onFindNewProduct: _findNewProduct,
          showFindNew: state.stage == FilterFlowStage.products,
        );

        if (!widget.sticky) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              SizedBox(height: context.rh(14)),
              content,
              SizedBox(height: context.rh(14)),
              footer,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: header,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: content,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: footer,
            ),
          ],
        );
      },
    );
  }
}

// ── Persistent header ─────────────────────────────────────────────────

/// Search, filter and the active-filter trail. Never hidden, at any stage.
class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onVoiceTap,
    required this.onImageTap,
    required this.onClearStep,
    required this.onClearCategory,
    required this.onBack,
  });

  final ProductFilterFlowState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onImageTap;
  final ValueChanged<String> onClearStep;
  final VoidCallback onClearCategory;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductSearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
          onFilterTap: onFilterTap,
          activeFilterCount: _activeFilterCount,
          onVoiceTap: onVoiceTap,
          onImageTap: onImageTap,
        ),
        // AnimatedSize rather than a conditional child, so the header grows
        // into the chip row instead of the content below it jumping.
        AnimatedSize(
          duration: FilterFlowTransition.duration,
          curve: FilterFlowTransition.curve,
          alignment: Alignment.topCenter,
          child: state.category == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: FilterChipBar(
                    categoryLabel: context.localized(state.category!.name),
                    selection: state.selection,
                    onClearStep: onClearStep,
                    onClearCategory: onClearCategory,
                    trailing: _BackButton(onPressed: onBack),
                  ),
                ),
        ),
      ],
    );
  }

  /// Category + answered steps + stock + non-default sort. Search is excluded:
  /// it has its own visible field, so counting it would double-report.
  int get _activeFilterCount {
    var count = state.selection.entries.length;
    if (state.category != null) count++;
    if (state.availableOnly) count++;
    if (state.sortBy.name != 'relevance') count++;
    return count;
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: 'common.back'.tr,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Icon(Icons.undo_rounded,
              size: context.rr(16), color: colors.textPrimary),
        ),
      ),
    );
  }
}

// ── Stage switcher ────────────────────────────────────────────────────

class _StageContent extends StatelessWidget {
  const _StageContent({
    required this.state,
    required this.favoriteIds,
    required this.quantityFor,
    required this.lineTotalFor,
    required this.onQuantityChanged,
    required this.onToggleFavorite,
    required this.onCustomize,
    required this.onProductTap,
    required this.onFindNewProduct,
    this.depotId,
    this.leadId,
    this.onInputPrice,
    this.hostManualPriceFor,
  });

  final ProductFilterFlowState state;
  final Set<String> favoriteIds;
  final int Function(Product product) quantityFor;
  final String Function(Product product, int quantity)? lineTotalFor;
  final void Function(Product product, int quantity) onQuantityChanged;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Product>? onCustomize;
  final ValueChanged<Product>? onProductTap;
  final VoidCallback onFindNewProduct;
  final String? depotId;
  final String? leadId;
  final Future<void> Function(Product product)? onInputPrice;
  final double? Function(Product product)? hostManualPriceFor;

  @override
  Widget build(BuildContext context) {
    return FilterFlowTransition(
      stageKey: _stageKey,
      child: switch (state.stage) {
        FilterFlowStage.categories => _CategoryStage(state: state),
        FilterFlowStage.steps => _StepStage(state: state),
        FilterFlowStage.products => _ProductStage(
            state: state,
            favoriteIds: favoriteIds,
            quantityFor: quantityFor,
            lineTotalFor: lineTotalFor,
            onQuantityChanged: onQuantityChanged,
            onToggleFavorite: onToggleFavorite,
            onCustomize: onCustomize,
            onProductTap: onProductTap,
            onFindNewProduct: onFindNewProduct,
            depotId: depotId,
            leadId: leadId,
            onInputPrice: onInputPrice,
            hostManualPriceFor: hostManualPriceFor,
          ),
      },
    );
  }

  /// Keyed on stage identity, not data: re-running the query after a keystroke
  /// must not replay the slide-in.
  Object get _stageKey => switch (state.stage) {
        FilterFlowStage.categories => 'categories',
        FilterFlowStage.steps => 'step:${state.activeStep?.key}',
        FilterFlowStage.products =>
          'products:${state.category?.code}:${state.hasSearch}',
      };
}

// ── Stage: category ───────────────────────────────────────────────────

class _CategoryStage extends StatelessWidget {
  const _CategoryStage({required this.state});
  final ProductFilterFlowState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == FilterFlowStatus.loading) {
      return LoadingProducts.grid(count: 6);
    }
    if (state.status == FilterFlowStatus.failure) {
      return _FailureState(message: state.errorMessage);
    }
    if (state.categories.isEmpty) {
      return EmptyProducts.chooseCategory(
        title: 'orders.guided_filter.no_categories_title'.tr,
        message: 'orders.guided_filter.no_categories_message'.tr,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageHeader(
          title: 'orders.guided_filter.choose_category'.tr,
          subtitle: 'orders.guided_filter.choose_category_hint'.tr,
        ),
        SizedBox(height: context.rh(12)),
        CategorySelector(
          categories: state.categories,
          selectedCategoryId: state.category?.code,
          onSelect: (category) => context
              .read<ProductFilterFlowBloc>()
              .add(FilterCategorySelected(category)),
        ),
      ],
    );
  }
}

// ── Stage: one filter step ────────────────────────────────────────────

class _StepStage extends StatelessWidget {
  const _StepStage({required this.state});
  final ProductFilterFlowState state;

  @override
  Widget build(BuildContext context) {
    final step = state.activeStep;
    if (step == null) return const SizedBox.shrink();

    final bloc = context.read<ProductFilterFlowBloc>();
    void select(FilterOption option) =>
        bloc.add(FilterStepAnswered(stepKey: step.key, option: option));

    final Widget selector;
    if (state.optionsLoading) {
      selector = step.role == FilterStepRole.family
          ? LoadingProducts.list()
          : (step.style == FilterStepStyle.grid
              ? LoadingProducts.grid()
              : LoadingProducts.chips());
    } else if (state.activeOptions.isEmpty) {
      selector = EmptyProducts.chooseFamily(
        title: 'orders.guided_filter.no_options_title'
            .trParams({'label': step.label}),
        message: 'orders.guided_filter.no_options_message'.tr,
      );
    } else if (step.role == FilterStepRole.family) {
      selector = ProductFamilySelector(
        options: state.activeOptions,
        selectedValue: state.selection.valueFor(step.key),
        countLabelBuilder: (count) =>
            'orders.guided_filter.items_count'.trParams({'count': count}),
        onSelect: select,
      );
    } else {
      selector = DynamicFilterSection(
        step: step,
        options: state.activeOptions,
        selectedValue: state.selection.valueFor(step.key),
        onSelect: select,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageHeader(
          title: 'orders.guided_filter.select_label'
              .trParams({'label': step.label}),
          subtitle: 'orders.guided_filter.step_progress'.trParams({
            'current': state.activeStepNumber,
            'total': state.totalSteps,
          }),
        ),
        SizedBox(height: context.rh(12)),
        selector,
      ],
    );
  }
}

// ── Stage: products ───────────────────────────────────────────────────

class _ProductStage extends StatelessWidget {
  const _ProductStage({
    required this.state,
    required this.favoriteIds,
    required this.quantityFor,
    required this.lineTotalFor,
    required this.onQuantityChanged,
    required this.onToggleFavorite,
    required this.onCustomize,
    required this.onProductTap,
    required this.onFindNewProduct,
    this.depotId,
    this.leadId,
    this.onInputPrice,
    this.hostManualPriceFor,
  });

  final ProductFilterFlowState state;
  final Set<String> favoriteIds;
  final int Function(Product product) quantityFor;
  final String Function(Product product, int quantity)? lineTotalFor;
  final void Function(Product product, int quantity) onQuantityChanged;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Product>? onCustomize;
  final ValueChanged<Product>? onProductTap;
  final VoidCallback onFindNewProduct;
  final String? depotId;
  final String? leadId;
  final Future<void> Function(Product product)? onInputPrice;
  final double? Function(Product product)? hostManualPriceFor;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProductFilterFlowBloc>();
    final loadingFirstPage = state.productStatus == ProductListStatus.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StageHeader(
                title: state.hasSearch
                    ? 'orders.guided_filter.matching_materials'.tr
                    : 'orders.guided_filter.results'.tr,
                subtitle: loadingFirstPage
                    ? null
                    : 'orders.guided_filter.results_count'
                        .trParams({'count': state.products.length}),
              ),
            ),
            FindNewProductButton.compact(context, onTap: onFindNewProduct),
          ],
        ),
        // Between the header and the results: the rep has the material, and
        // this is where they choose which plant supplies it. Renders itself
        // away when there is only one.
        if (state.hasStockLocationChoice) ...[
          SizedBox(height: context.rh(4)),
          StockLocationChips(
            options: state.stockLocations,
            selectedCode: state.stockLocationCode,
            onSelect: (code) => bloc.add(FilterStockLocationChanged(code)),
          ),
        ],
        SizedBox(height: context.rh(10)),
        if (loadingFirstPage)
          LoadingProducts.products()
        else if (state.productStatus == ProductListStatus.failure)
          _FailureState(message: state.errorMessage)
        else if (state.products.isEmpty)
          EmptyProducts.noResults(
            title: 'orders.guided_filter.no_results_title'.tr,
            message: state.hasSearch
                ? 'orders.guided_filter.no_search_results_message'.tr
                : 'orders.guided_filter.no_results_message'.tr,
            action: TextButton.icon(
              onPressed: () => bloc.add(const FilterFlowBackRequested()),
              icon: Icon(Icons.arrow_back_rounded, size: context.rr(16)),
              label: Text('orders.guided_filter.change_filters'.tr),
            ),
          )
        else ...[
          // Rebuilds on cart changes so a `+` tap is reflected on the card
          // that produced it — the stepper is the commit, so it has to show
          // the committed value, not a local echo of it.
          BlocBuilder<CartCubit, CartState>(
            builder: (context, cartState) =>
                BlocBuilder<PromotionCubit, Map<String, PromotionEvaluation>>(
              builder: (context, promotions) {
                // In search mode, evaluate promotions only for the selected product.
                // In guided filter mode, evaluate for all products in the current step.
                final productsToEvaluate = state.hasSearch
                    ? (state.selectedProduct != null
                        ? [state.selectedProduct!]
                        : const <Product>[])
                    : state.products;

                for (final product in productsToEvaluate) {
                  context.read<PromotionCubit>().evaluate(
                        materialCode: product.materialCode,
                        categoryCode: product.categoryId,
                        quantity: quantityFor(product),
                      );
                }

                double? manualPriceFor(
                    Product product, Map<String, MobilePrice> prices) {
                  final p = prices[product.materialNumber];
                  if (p != null && p.hasAmount) return null;

                  final fromHost = hostManualPriceFor?.call(product);
                  if (fromHost != null && fromHost > 0) return fromHost;

                  if (cartState is! CartLoaded) return null;
                  for (final item in cartState.items) {
                    if (item.product.id == product.id &&
                        (depotId == null || item.depotId == depotId) &&
                        (leadId == null || item.leadId == leadId) &&
                        item.isManualPrice &&
                        item.unitPriceOverride != null) {
                      return item.unitPriceOverride;
                    }
                  }
                  for (final item in cartState.items) {
                    if (item.product.id == product.id &&
                        item.isManualPrice &&
                        item.unitPriceOverride != null) {
                      return item.unitPriceOverride;
                    }
                  }
                  return null;
                }

                Future<void> handleInputPrice(
                    Product product, Map<String, MobilePrice> prices) async {
                  final p = prices[product.materialNumber];
                  if (p != null && p.hasAmount) {
                    // Backend already succeeded for this material! Manual price is disallowed.
                    return;
                  }

                  if (onInputPrice != null) {
                    await onInputPrice!(product);
                    return;
                  }

                  final cart = context.read<CartCubit>();
                  final cState = cart.state;
                  CartItem? existingItem;
                  if (cState is CartLoaded) {
                    for (final item in cState.items) {
                      if (item.product.id == product.id &&
                          (depotId == null || item.depotId == depotId) &&
                          (leadId == null || item.leadId == leadId)) {
                        existingItem = item;
                        break;
                      }
                    }
                    if (existingItem == null) {
                      for (final item in cState.items) {
                        if (item.product.id == product.id) {
                          existingItem = item;
                          break;
                        }
                      }
                    }
                  }

                  final entered = await showManualPriceInputSheet(
                    context: context,
                    product: product,
                    unit: product.unit,
                    currentPrice: existingItem?.isManualPrice == true
                        ? existingItem?.unitPriceOverride
                        : manualPriceFor(product, prices),
                  );

                  if (entered == null || !context.mounted) return;

                  if (existingItem != null) {
                    await cart.updateUnitPrice(
                      existingItem.id,
                      entered > 0 ? entered : null,
                      isManualPrice: true,
                    );
                  } else if (entered > 0) {
                    await cart.addProduct(
                      product,
                      quantity: 1,
                      unit: product.unit,
                      depotId: depotId,
                      leadId: leadId,
                      unitPrice: entered,
                      isManualPrice: true,
                    );
                  }
                }

                final productsToPrice = state.hasSearch
                    ? (state.selectedProduct != null
                        ? [state.selectedProduct!]
                        : const <Product>[])
                    : state.products;

                return _PricedResults(
                  products: productsToPrice,
                  builder: (context, prices) {
                    if (state.hasSearch) {
                      return Column(
                        children: [
                          for (var i = 0; i < state.products.length; i++)
                            Builder(
                              key: ValueKey(state.products[i].id),
                              builder: (context) {
                                final product = state.products[i];
                                final isSelected = state.selectedSku != null &&
                                    (state.selectedSku == product.sku ||
                                        state.selectedSku == product.id ||
                                        state.selectedSku == product.code ||
                                        state.selectedSku ==
                                            product.materialCode);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SkuSearchCard(
                                        product: product,
                                        isSelected: isSelected,
                                        specLine: _specLine(product),
                                        onTap: () {
                                          final idToSelect =
                                              product.sku.isNotEmpty
                                                  ? product.sku
                                                  : product.id;
                                          bloc.add(FilterProductSkuSelected(
                                              isSelected ? null : idToSelect));
                                        },
                                      ),
                                      if (isSelected) ...[
                                        SizedBox(height: context.rh(8)),
                                        ProductResultCard(
                                          product: product,
                                          isFavorite:
                                              favoriteIds.contains(product.id),
                                          quantity: quantityFor(product),
                                          specLine: _specLine(product),
                                          lineTotalLabel: lineTotalFor?.call(
                                              product, quantityFor(product)),
                                          onQuantityChanged: (value) =>
                                              onQuantityChanged(product, value),
                                          onToggleFavorite: () =>
                                              onToggleFavorite(product),
                                          onTap: onProductTap == null
                                              ? null
                                              : () => onProductTap!(product),
                                          onCustomize: onCustomize == null
                                              ? null
                                              : () => onCustomize!(product),
                                          promotion:
                                              promotions[product.materialCode],
                                          onPromotionTap: () {
                                            final evaluation = promotions[
                                                product.materialCode];
                                            if (evaluation == null) return;
                                            showPromotionDetailSheet(
                                              context,
                                              promotion: evaluation.promotion,
                                              evaluation: evaluation,
                                            );
                                          },
                                          price: prices[product.materialNumber],
                                          manualPrice:
                                              manualPriceFor(product, prices),
                                          onInputPrice:
                                              (prices[product.materialNumber]
                                                          ?.hasAmount ==
                                                      true)
                                                  ? null
                                                  : () => handleInputPrice(
                                                      product, prices),
                                          onPriceRetry: () => context
                                              .read<PricingCubit>()
                                              .retry(product.materialNumber),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    }

                    return ProductResultGrid(
                      products: state.products,
                      favoriteIds: favoriteIds,
                      quantityFor: quantityFor,
                      lineTotalBuilder: lineTotalFor,
                      onQuantityChanged: onQuantityChanged,
                      onToggleFavorite: onToggleFavorite,
                      onCustomize: onCustomize,
                      onTap: onProductTap,
                      specLineBuilder: _specLine,
                      promotionFor: (product) =>
                          promotions[product.materialCode],
                      onPromotionTap: (product) {
                        final evaluation = promotions[product.materialCode];
                        if (evaluation == null) return;
                        showPromotionDetailSheet(
                          context,
                          promotion: evaluation.promotion,
                          evaluation: evaluation,
                        );
                      },
                      // Keyed by SAP material number, not by row id: the pricing
                      // endpoint answers per material, and the same material
                      // stocked at three warehouses is three rows that share one
                      // price.
                      priceFor: (product) => prices[product.materialNumber],
                      manualPriceFor: (product) =>
                          manualPriceFor(product, prices),
                      onInputPrice: (product) =>
                          handleInputPrice(product, prices),
                      onPriceRetry: (product) => context
                          .read<PricingCubit>()
                          .retry(product.materialNumber),
                    );
                  },
                );
              },
            ),
          ),
          if (state.hasMore)
            Center(
              child: state.productStatus == ProductListStatus.loadingMore
                  ? Padding(
                      padding: EdgeInsets.all(context.rr(12)),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: () =>
                          bloc.add(const FilterProductsLoadMoreRequested()),
                      child: Text('orders.catalog.load_more'.tr),
                    ),
            ),
        ],
      ],
    );
  }

  /// The answered filters echoed back on the card, so the rep can confirm at a
  /// glance that this row is the 0.30 mm x 3.90 m they asked for. On a direct
  /// search there are no answers, so the SKU's own size stands in.
  String _specLine(Product product) {
    if (state.selection.isEmpty) return product.size;
    return [for (final e in state.selection.entries) e.option.label]
        .join(' · ');
  }
}

/// Keeps [PricingCubit] asking about exactly the materials on screen, and
/// hands the resulting prices to [builder].
///
/// ## Why this is stateful
///
/// [PricingCubit.track] emits its loading state *synchronously*. Calling it
/// from inside a `build` — which is where the promotion equivalent is called,
/// because that one is timer-debounced — would mutate a cubit during the build
/// that is reading it, which Flutter rejects outright. So the request is
/// scheduled after the frame instead.
///
/// ## Why it asks for everything on screen at once
///
/// The endpoint takes a repeatable `materials` parameter, so a page of results
/// costs one round trip rather than one per card. The list is built lazily as
/// the rep scrolls, which keeps that batch to what is actually being looked at
/// — the endpoint's own guidance is that naming a few materials is much faster
/// than naming forty.
class _PricedResults extends StatefulWidget {
  const _PricedResults({required this.products, required this.builder});

  final List<Product> products;
  final Widget Function(BuildContext context, Map<String, MobilePrice> prices)
      builder;

  @override
  State<_PricedResults> createState() => _PricedResultsState();
}

class _PricedResultsState extends State<_PricedResults> {
  /// What has already been handed to the cubit, so a rebuild does not schedule
  /// a callback per frame on a list the rep is scrolling.
  final Set<String> _requested = {};

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didUpdateWidget(covariant _PricedResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    _track();
  }

  void _track() {
    final fresh = <String>{
      for (final product in widget.products)
        if (product.materialNumber.trim().isNotEmpty) product.materialNumber,
    }..removeAll(_requested);
    if (fresh.isEmpty) return;

    _requested.addAll(fresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The cubit is idempotent and skips anything already priced, so a
      // duplicate here costs nothing.
      unawaited(context.read<PricingCubit>().track(fresh));
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PricingCubit, Map<String, MobilePrice>>(
        builder: widget.builder,
      );
}

// ── Footer ────────────────────────────────────────────────────────────

class _CartFooter extends StatelessWidget {
  const _CartFooter({
    required this.onTap,
    required this.onFindNewProduct,
    required this.showFindNew,
  });

  final VoidCallback? onTap;
  final VoidCallback onFindNewProduct;
  final bool showFindNew;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final items =
            cartState is CartLoaded ? cartState.items : const <CartItem>[];
        if (items.isEmpty) return const SizedBox(width: double.infinity);

        final totalQuantity =
            items.fold<double>(0, (sum, item) => sum + item.quantity);
        // Null as soon as one line is unpriced — see [CartSummaryBar.subtotal].
        final subtotal = cartState is CartLoaded
            ? (items.hasPendingPricing ? null : cartState.subtotal)
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CartSummaryBar(
              lineCount: items.length,
              totalQuantity: totalQuantity,
              subtotal: subtotal,
              onTap: onTap,
            ),
            // Only offered once something is in the quotation and products are
            // on screen — before that there is nothing to move on from.
            if (showFindNew) ...[
              SizedBox(height: context.rh(10)),
              FindNewProductButton(onPressed: onFindNewProduct),
            ],
          ],
        );
      },
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(16),
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: context.rh(3)),
          Text(
            subtitle!,
            style: TextStyle(
                color: colors.textSecondary, fontSize: context.rsp(12)),
          ),
        ],
      ],
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => EmptyProducts(
        icon: Icons.error_outline_rounded,
        title: 'orders.guided_filter.error_title'.tr,
        message: message,
        action: TextButton(
          onPressed: () => context
              .read<ProductFilterFlowBloc>()
              .add(const FilterFlowStarted()),
          child: Text('common.retry'.tr),
        ),
      );
}
