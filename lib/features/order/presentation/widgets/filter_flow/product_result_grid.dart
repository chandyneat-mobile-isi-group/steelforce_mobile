import 'package:flutter/material.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_result_card.dart';

/// The resolved product list — the last stage of the flow, and the only one
/// that touches product data.
///
/// A thin arranger over [ProductResultCard]: it owns the stagger and the
/// spacing, nothing else. Everything a card needs is resolved by the caller
/// through the builders, which is what keeps this reusable outside the guided
/// flow (favourites, search results, a future re-order screen).
class ProductResultGrid extends StatelessWidget {
  const ProductResultGrid({
    super.key,
    required this.products,
    required this.favoriteIds,
    required this.quantityFor,
    required this.onQuantityChanged,
    required this.onToggleFavorite,
    this.onTap,
    this.onCustomize,
    this.specLineBuilder,
    this.lineTotalBuilder,
    this.promotionFor,
    this.onPromotionTap,
    this.priceFor,
    this.manualPriceFor,
    this.onInputPrice,
    this.onPriceRetry,
  });

  final List<Product> products;
  final Set<String> favoriteIds;

  /// Current cart quantity for a product — the card renders it, never stores
  /// it.
  final int Function(Product product) quantityFor;

  final void Function(Product product, int quantity) onQuantityChanged;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Product>? onTap;

  /// Shows the per-card "customize" action when provided.
  final ValueChanged<Product>? onCustomize;

  final String Function(Product product)? specLineBuilder;
  final String Function(Product product, int quantity)? lineTotalBuilder;

  /// The promotion verdict for a product, or null when none applies.
  ///
  /// A builder rather than a map so this grid stays reusable on screens that
  /// have no promotion context — they pass nothing and no card shows a strip.
  final PromotionEvaluation? Function(Product product)? promotionFor;

  final ValueChanged<Product>? onPromotionTap;

  /// This depot's price for a product, or null when the screen has no
  /// pricing context.
  ///
  /// A builder for the same reason as [promotionFor]: screens with no depot
  /// — favourites, a plain catalogue browse — pass nothing and no card shows a
  /// figure, rather than every card showing an empty one.
  final MobilePrice? Function(Product product)? priceFor;

  /// Manual unit price override for a product, if entered.
  final double? Function(Product product)? manualPriceFor;

  /// Handler for inputting or editing a manual price on a product card.
  final ValueChanged<Product>? onInputPrice;

  /// Re-asks for one product's failed price.
  final ValueChanged<Product>? onPriceRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < products.length; i++)
          FilterFlowStaggeredItem(
            // Keyed by SKU rather than by position: the stepper below carries
            // a local quantity, and a re-filtered list that shifts rows would
            // otherwise hand one product's pending number to another.
            key: ValueKey(products[i].id),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Builder(builder: (context) {
                final product = products[i];
                final quantity = quantityFor(product);
                final p = priceFor?.call(product);
                final hasBackendPrice = p != null && p.hasAmount;
                return ProductResultCard(
                  product: product,
                  isFavorite: favoriteIds.contains(product.id),
                  quantity: quantity,
                  specLine: specLineBuilder?.call(product),
                  lineTotalLabel: lineTotalBuilder?.call(product, quantity),
                  onQuantityChanged: (value) =>
                      onQuantityChanged(product, value),
                  onToggleFavorite: () => onToggleFavorite(product),
                  onTap: onTap == null ? null : () => onTap!(product),
                  onCustomize:
                      onCustomize == null ? null : () => onCustomize!(product),
                  promotion: promotionFor?.call(product),
                  onPromotionTap: onPromotionTap == null
                      ? null
                      : () => onPromotionTap!(product),
                  price: p,
                  manualPrice:
                      hasBackendPrice ? null : manualPriceFor?.call(product),
                  onInputPrice: (hasBackendPrice || onInputPrice == null)
                      ? null
                      : () => onInputPrice!(product),
                  onPriceRetry: onPriceRetry == null
                      ? null
                      : () => onPriceRetry!(product),
                );
              }),
            ),
          ),
      ],
    );
  }
}
