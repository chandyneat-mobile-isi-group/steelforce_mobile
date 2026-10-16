import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_tier.dart';

/// The free-goods offer on a cart line, pinned to the card's top-right corner.
///
/// ## Why only free goods
///
/// A percentage discount already shows on the line, next to the unit price,
/// where a rep reads it against the number it modifies. Free goods have nowhere
/// like that to live: they change the *quantity*, not the price, and the paid
/// quantity sits in a stepper the rep is actively driving. Putting "+1 free"
/// inside that stepper would make the number they are adjusting disagree with
/// the number they are reading.
///
/// So this is the one promotion shape that earns its own corner. Percentage
/// discounts, clearance and monthly deals keep rendering exactly where they do
/// now.
///
/// ## Why the corner rather than a strip
///
/// The catalog card has room for [PromotionInlineBlock] — a full strip with a
/// progress bar, because a rep browsing there is deciding *whether* to buy. In
/// the cart they have already decided; the line is a commitment being checked.
/// A strip would push every cart line taller for information that is now a
/// confirmation rather than a prompt, and cart height is the whole ergonomic
/// budget on a screen a rep scrolls back through a dozen times.
///
/// The corner is also where a discount sticker sits on a physical shelf tag,
/// which is what a rep is used to reading.
///
/// ## What it says
///
/// "Buy 40 Free 1", taken verbatim from the tier. Not "5% off" — the two are
/// different promises and only one of them is checkable at the counter. A rep
/// saying "buy forty and one comes free" can be held to it; "about 2.4% off"
/// invites an argument about the arithmetic.
class CartPromotionBadge extends StatelessWidget {
  const CartPromotionBadge({
    super.key,
    required this.evaluation,
    this.onSeeDetail,
  });

  final PromotionEvaluation evaluation;

  /// Opens the full ladder. Null hides the button, which is the right shape for
  /// a read-only context such as a submitted order.
  final VoidCallback? onSeeDetail;

  /// The rung worth showing.
  ///
  /// The earned one when there is one — that is what the depot is actually
  /// getting, and it must not be displaced by an upsell. Otherwise the next
  /// rung, which turns the badge from a notice into a prompt: a line sitting at
  /// 30 against a 40-tier should say what reaching 40 would earn.
  PromotionTier? get _tier => evaluation.earnedTier ?? evaluation.nextTier;

  @override
  Widget build(BuildContext context) {
    final tier = _tier;
    if (tier == null) return const SizedBox.shrink();

    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final earned = evaluation.isEligible;

    // Earned reads as confirmation, unearned as an invitation. Same badge, two
    // weights — a rep glancing down a cart needs to tell "they have it" from
    // "they could have it" without reading either label.
    final accent = earned ? colors.success : scheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: earned ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      padding: EdgeInsets.fromLTRB(
        context.rw(8),
        context.rh(3),
        onSeeDetail == null ? context.rw(8) : context.rw(4),
        context.rh(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            earned ? Icons.card_giftcard_rounded : Icons.local_offer_rounded,
            size: context.rr(11),
            color: accent,
          ),
          SizedBox(width: context.rw(4)),
          // Flexible so a long ladder label ellipsizes instead of overflowing
          // a narrow cart row. The badge sits in a bounded slot; an unbounded
          // Text here would paint straight through whatever is beside it.
          Flexible(
            child: Text(
              'Buy ${tier.minQuantity} Free ${tier.freeQuantity}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: context.rsp(10.5),
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          if (onSeeDetail != null) ...[
            SizedBox(width: context.rw(2)),

            // Its own tap target rather than making the whole badge tappable.
            // The badge overlaps a card that is itself tappable, and a rep
            // aiming for the line would otherwise land on a sheet instead.
            InkWell(
              onTap: onSeeDetail,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(5),
                  vertical: context.rh(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See detail',
                      style: TextStyle(
                        color: accent,
                        fontSize: context.rsp(9.5),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: accent,
                        height: 1.1,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: context.rr(11),
                      color: accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
