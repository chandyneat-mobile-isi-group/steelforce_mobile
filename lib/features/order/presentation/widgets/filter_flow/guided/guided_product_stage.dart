import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/bloc/promotion/promotion_cubit.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/empty_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/find_new_product_button.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/filter_failure_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/filter_stage_header.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/guided_sku_search_results.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/priced_results.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/loading_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_grid.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/stock_location_chips.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/promotion_detail_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/manual_price_input_sheet.dart';

/// The results stage: the matching materials, priced, with their promotions
/// and the manual-price fallback for a material SAP returned no price for.
class GuidedProductStage extends StatelessWidget {
  const GuidedProductStage({
    super.key,
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
              child: FilterStageHeader(
                title: state.hasSearch
                    ? 'Matching Materials'
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
          FilterFailureState(message: state.errorMessage)
        else if (state.products.isEmpty)
          EmptyProducts.noResults(
            title: 'orders.guided_filter.no_results_title'.tr,
            message: state.hasSearch
                ? 'Try another SKU or material name.'
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
              builder: (context, promotions) =>
                  _results(context, cartState, promotions),
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

  Widget _results(
    BuildContext context,
    CartState cartState,
    Map<String, PromotionEvaluation> promotions,
  ) {
    // In search mode only the selected product is evaluated and priced; in
    // guided mode, every product on the current step.
    final visibleProducts = state.hasSearch
        ? (state.selectedProduct != null
            ? [state.selectedProduct!]
            : const <Product>[])
        : state.products;

    for (final product in visibleProducts) {
      context.read<PromotionCubit>().evaluate(
            materialCode: product.materialCode,
            categoryCode: product.categoryId,
            quantity: quantityFor(product),
          );
    }

    void showPromotion(Product product) {
      final evaluation = promotions[product.materialCode];
      if (evaluation == null) return;
      showPromotionDetailSheet(
        context,
        promotion: evaluation.promotion,
        evaluation: evaluation,
      );
    }

    return PricedResults(
      products: visibleProducts,
      builder: (pricedContext, prices) {
        if (state.hasSearch) {
          return GuidedSkuSearchResults(
            state: state,
            prices: prices,
            promotions: promotions,
            favoriteIds: favoriteIds,
            quantityFor: quantityFor,
            lineTotalFor: lineTotalFor,
            onQuantityChanged: onQuantityChanged,
            onToggleFavorite: onToggleFavorite,
            onProductTap: onProductTap,
            onCustomize: onCustomize,
            specLine: _specLine,
            manualPriceFor: (product) =>
                _manualPriceFor(product, prices, cartState),
            onInputPrice: (product) =>
                _handleInputPrice(context, product, prices, cartState),
            onPromotionTap: showPromotion,
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
          promotionFor: (product) => promotions[product.materialCode],
          onPromotionTap: showPromotion,
          // Keyed by SAP material number, not by row id: the pricing
          // endpoint answers per material, and the same material
          // stocked at three warehouses is three rows that share one
          // price.
          priceFor: (product) => prices[product.materialNumber],
          manualPriceFor: (product) =>
              _manualPriceFor(product, prices, cartState),
          onInputPrice: (product) =>
              _handleInputPrice(context, product, prices, cartState),
          onPriceRetry: (product) =>
              pricedContext.read<PricingCubit>().retry(product.materialNumber),
        );
      },
    );
  }

  /// The rep's own price for a material SAP did not price, or null. The host's
  /// value wins, then a manual line for this depot/lead, then any manual line.
  double? _manualPriceFor(
    Product product,
    Map<String, MobilePrice> prices,
    CartState cartState,
  ) {
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

  Future<void> _handleInputPrice(
    BuildContext context,
    Product product,
    Map<String, MobilePrice> prices,
    CartState cartState,
  ) async {
    final p = prices[product.materialNumber];
    if (p != null && p.hasAmount) {
      // SAP priced this material, so a manual price is not allowed.
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
          : _manualPriceFor(product, prices, cartState),
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

  /// The answered filters echoed back on the card, so the rep can confirm at a
  /// glance that this row is the 0.30 mm x 3.90 m they asked for. On a direct
  /// search there are no answers, so the SKU's own size stands in.
  String _specLine(Product product) {
    if (state.selection.isEmpty) return product.size;
    return [for (final e in state.selection.entries) e.option.label]
        .join(' · ');
  }
}
