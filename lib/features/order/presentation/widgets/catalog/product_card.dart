import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/promotion_badge.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.onTap,
    required this.isFavorite,
    required this.product,
    required this.onFavoriteToggle,
    required this.onAddToCart,
    this.onCustomize,
  });

  final Product product;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onAddToCart;

  /// When set, shows a "customize" action that opens the category-aware
  /// customization form instead of adding the plain product.
  final VoidCallback? onCustomize;

  static const _imageSize = 58.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appColors = context.appColors;

    // The material's own unit, off the row. Identification, not a stock read.
    final baseUnit = product.unit;
    final placeholder = Container(
      color: appColors.surfaceSoft,
      child: Icon(Icons.inventory_2_outlined,
          color: scheme.onSurface.withValues(alpha: 0.4), size: context.rr(24)),
    );

    return GlassCard(
      padding: EdgeInsets.all(context.rr(8)),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: _imageSize,
                  height: _imageSize,
                  // No URL means no image, not a request for "": the
                  // selection API and a demo build both send none.
                  child: product.imageUrl.isEmpty
                      ? placeholder
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => placeholder,
                        ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: onFavoriteToggle,
                  child: Container(
                    padding: EdgeInsets.all(context.rr(3)),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: context.rr(14),
                      color: isFavorite
                          ? scheme.error
                          : scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              if (product.hasPromotion)
                const Positioned(
                    top: 2, left: 2, child: PromotionBadge(label: 'Sale')),
            ],
          ),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (product.code.isNotEmpty)
                  Text(
                    product.code,
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontSize: context.rsp(10),
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  context.localized(product.displayName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: context.rsp(12.5),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                // Identification only: what the material is and what it sells
                // by. No band and no amount — neither is known here, and
                // neither is needed to put it in the cart.
                if (product.familyName.isNotEmpty || baseUnit.isNotEmpty) ...[
                  SizedBox(height: context.rh(3)),
                  Text(
                    [
                      if (product.familyName.isNotEmpty) product.familyName,
                      if (baseUnit.isNotEmpty) baseUnit,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                      fontSize: context.rsp(10.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                SizedBox(height: context.rh(6)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onCustomize != null) ...[
                      InkWell(
                        onTap: onCustomize,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.tune_rounded,
                              size: context.rr(16), color: scheme.primary),
                        ),
                      ),
                      SizedBox(width: context.rw(6)),
                    ],
                    // Never gated. Any catalogue material may be added;
                    // stock and price are settled later in the flow.
                    _AddButton(onTap: onAddToCart),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The `+` action.
///
/// Unconditional: adding a material to the cart no longer depends on stock or
/// price. It used to dim on a stock verdict, which meant a rep could not put a
/// catalogue material on a quotation because SAP had not been asked — or had
/// answered about a plant they were not selling from.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add_shopping_cart_rounded,
            size: context.rr(16), color: scheme.onPrimary),
      ),
    );
  }
}
