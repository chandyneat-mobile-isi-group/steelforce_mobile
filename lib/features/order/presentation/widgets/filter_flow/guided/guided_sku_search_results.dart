import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_card.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/sku_search_card.dart';

/// Search-mode results: a compact SKU card per match, with the full product
/// card expanded under the one the rep selected.
class GuidedSkuSearchResults extends StatelessWidget {
  const GuidedSkuSearchResults({
    super.key,
    required this.state,
    required this.prices,
    required this.promotions,
    required this.favoriteIds,
    required this.quantityFor,
    required this.lineTotalFor,
    required this.onQuantityChanged,
    required this.onToggleFavorite,
    required this.onProductTap,
    required this.onCustomize,
    required this.specLine,
    required this.manualPriceFor,
    required this.onInputPrice,
    required this.onPromotionTap,
  });

  final ProductFilterFlowState state;
  final Map<String, MobilePrice> prices;
  final Map<String, PromotionEvaluation> promotions;
  final Set<String> favoriteIds;
  final int Function(Product product) quantityFor;
  final String Function(Product product, int quantity)? lineTotalFor;
  final void Function(Product product, int quantity) onQuantityChanged;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Product>? onProductTap;
  final ValueChanged<Product>? onCustomize;
  final String Function(Product product) specLine;
  final double? Function(Product product) manualPriceFor;
  final Future<void> Function(Product product) onInputPrice;
  final ValueChanged<Product> onPromotionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final product in state.products)
          Builder(
            key: ValueKey(product.id),
            builder: (context) => _resultFor(context, product),
          ),
      ],
    );
  }

  Widget _resultFor(BuildContext context, Product product) {
    final isSelected = state.selectedSku != null &&
        (state.selectedSku == product.sku ||
            state.selectedSku == product.id ||
            state.selectedSku == product.code ||
            state.selectedSku == product.materialCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkuSearchCard(
            product: product,
            isSelected: isSelected,
            specLine: specLine(product),
            onTap: () {
              final idToSelect =
                  product.sku.isNotEmpty ? product.sku : product.id;
              context.read<ProductFilterFlowBloc>().add(
                  FilterProductSkuSelected(isSelected ? null : idToSelect));
            },
          ),
          if (isSelected) ...[
            SizedBox(height: context.rh(8)),
            ProductResultCard(
              product: product,
              isFavorite: favoriteIds.contains(product.id),
              quantity: quantityFor(product),
              specLine: specLine(product),
              lineTotalLabel: lineTotalFor?.call(product, quantityFor(product)),
              onQuantityChanged: (value) => onQuantityChanged(product, value),
              onToggleFavorite: () => onToggleFavorite(product),
              onTap: onProductTap == null ? null : () => onProductTap!(product),
              onCustomize:
                  onCustomize == null ? null : () => onCustomize!(product),
              promotion: promotions[product.materialCode],
              onPromotionTap: () => onPromotionTap(product),
              price: prices[product.materialNumber],
              manualPrice: manualPriceFor(product),
              onInputPrice: (prices[product.materialNumber]?.hasAmount == true)
                  ? null
                  : () => onInputPrice(product),
              onPriceRetry: () =>
                  context.read<PricingCubit>().retry(product.materialNumber),
            ),
          ],
        ],
      ),
    );
  }
}
