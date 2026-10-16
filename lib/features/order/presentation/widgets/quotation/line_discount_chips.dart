import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/demo_cart_promotions.dart';

/// What came off one line, and on whose authority.
///
/// **Independent of pricing, on purpose.** The percentage and the free-goods
/// ladder are both known the moment a line is added; the money is not known
/// until the pricing call returns. Tying the two together is what made a
/// correctly applied ten percent look like it had never been granted on any
/// unpriced line. A rep at a counter has to be able to say "ten percent, and
/// one in forty free" whether or not the total has arrived.
///
/// **One implementation, three screens.** The builder's cart rows, the
/// quotation preview and the sales-order lines all render this. Written three
/// times they would drift, and the first divergence a rep notices is the one
/// where the cart and the quotation disagree about what the depot is getting
/// — which is the moment they stop believing either.
///
/// Renders nothing at all for an undiscounted line. An empty discount slot on
/// every ordinary row would be noise on the busiest screen in the app.
class LineDiscountChips extends StatelessWidget {
  const LineDiscountChips({
    super.key,
    required this.item,
    this.compact = false,
  });

  final CartItem item;

  /// Drops the source labels and shrinks the type, for a dense cart row where
  /// the figure matters more than its provenance. The full attribution is one
  /// scroll away on the quotation preview.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final percent = item.discountPercent;
    final freeQuantity = DemoCartPromotions.freeQuantityFor(item);
    final freeRule = DemoCartPromotions.freeRuleFor(item);
    final promotionName = DemoCartPromotions.promotionNameFor(item);

    if (percent <= 0 && freeQuantity <= 0) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: context.rh(3)),
      child: Wrap(
        spacing: context.rw(5),
        runSpacing: context.rh(3),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // The percentage gets its own chip: it is the figure a depot
          // repeats back, and the one they will check against the total once
          // the total exists.
          if (percent > 0)
            _Chip(
              icon: Icons.sell_outlined,
              label: '-${percent.toStringAsFixed(0)}%',
              detail: compact ? null : 'Rep discount',
              color: colors.success,
            ),

          // Free goods are not a percentage and must never be shown as one.
          // The rule is what makes the promise checkable at the counter: "buy
          // 40, one free" can be verified against the delivery, where "about
          // 2.4% off" only invites an argument about the arithmetic.
          if (freeQuantity > 0 && freeRule != null)
            _Chip(
              icon: Icons.card_giftcard_rounded,
              label: freeRule,
              detail: compact ? null : promotionName,
              color: colors.brandNavy,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final source = detail?.trim();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(6),
        vertical: context.rh(2),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rr(10), color: color),
          SizedBox(width: context.rw(3)),
          Text(
            label,
            style: TextStyle(
              fontSize: context.rsp(10),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          // The attribution, muted so it reads as a footnote to the figure
          // beside it rather than competing with it.
          if (source != null && source.isNotEmpty) ...[
            SizedBox(width: context.rw(4)),
            Flexible(
              child: Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.rsp(9.5),
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
