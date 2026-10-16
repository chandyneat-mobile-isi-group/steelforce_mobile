import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_tier.dart';

/// The promotion, shown where the rep is already looking: on the product card,
/// under the material they just picked.
///
/// ## Why it lives on the card
///
/// The alternative a rep would otherwise face is: open Promotions, search the
/// product, read the rule, go back, find the product again. The incentive has
/// to be at the moment of the decision or it may as well not exist — so this is
/// a strip inside the card, not a component beside it.
///
/// ## The four states
///
/// | State | Condition | Renders |
/// |---|---|---|
/// | A — none | `evaluation == null` | **nothing at all** |
/// | B — eligible | `earnedTier != null` | "Eligible: Free 15" |
/// | C — near a tier | `earnedTier == null`, `nextTier != null` | "Buy 20 more → Free 15" + progress |
/// | D — laddered | more than one tier | current rung ✓, next rung → |
///
/// State A rendering nothing is load-bearing. An empty promotion strip on
/// every unpromoted product would be permanent noise on the busiest screen in
/// the app, and it would train reps to stop looking at the one place the
/// promotion actually appears.
///
/// Nothing here decides eligibility. [PromotionEvaluation] arrives already
/// resolved; this widget only formats it. A card that worked out for itself
/// whether 280 bags qualified would be a second implementation of a commercial
/// rule, and it would drift from the real one.
class PromotionInlineBlock extends StatelessWidget {
  const PromotionInlineBlock({
    super.key,
    required this.evaluation,
    this.onTap,
    this.compact = false,
  });

  /// Null for state A — the widget collapses to nothing.
  final PromotionEvaluation? evaluation;

  /// Opens the detail sheet. The whole strip is the target, not a small icon.
  final VoidCallback? onTap;

  /// Drops the tier ladder, for a row too tight to carry it.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final result = evaluation;
    if (result == null) return const SizedBox.shrink();

    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    // Eligible reads as a benefit already earned; not-yet reads as a prompt.
    // Two different jobs, so two different weights — but the same family of
    // colour, because it is one feature and a second hue would read as a
    // second concept.
    final accent = result.isEligible ? colors.success : colors.warningAlt;

    return Semantics(
      button: onTap != null,
      label: _semanticLabel(context, result),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rr(10)),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(10),
              vertical: context.rh(8),
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(context.rr(10)),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Headline(result: result, accent: accent),
                if (!compact && result.hasMultipleTiers) ...[
                  SizedBox(height: context.rh(6)),
                  _TierLadder(result: result, accent: accent),
                ],
                if (!compact && result.progressToNextTier != null) ...[
                  SizedBox(height: context.rh(6)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.rr(4)),
                    child: LinearProgressIndicator(
                      value: result.progressToNextTier,
                      minHeight: context.rh(3),
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Spoken as one sentence rather than as a pile of fragments — a screen
  /// reader announcing "gift, promotion, buy, 20, more" conveys nothing.
  String _semanticLabel(BuildContext context, PromotionEvaluation result) {
    final title = context.localized(result.promotion.title);
    return '$title. ${_benefitLine(context, result)}';
  }
}

String _benefitLine(BuildContext context, PromotionEvaluation result) {
  final unit = result.promotion.unitLabel;

  if (result.isEligible) {
    return 'orders.promotion.eligible_free'
        .trParams({'free': '${result.freeQuantity} $unit'.trim()});
  }

  final gap = result.quantityToNextTier;
  final next = result.nextTier;
  if (gap != null && next != null) {
    // The sentence that turns a notice into a prompt — something a rep can say
    // out loud on a shop floor.
    return 'orders.promotion.buy_more'.trParams({
      'qty': '$gap',
      'unit': unit,
      'free': '${next.freeQuantity}',
    });
  }

  final first =
      result.promotion.tiers.isEmpty ? null : result.promotion.tiers.first;
  if (first == null) return '';
  return 'orders.promotion.buy_get'.trParams({
    'qty': '${first.minQuantity}',
    'unit': unit,
    'free': '${first.freeQuantity}',
  });
}

class _Headline extends StatelessWidget {
  const _Headline({required this.result, required this.accent});

  final PromotionEvaluation result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Icon(Icons.card_giftcard_rounded, size: context.rr(14), color: accent),
        SizedBox(width: context.rw(6)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.isEligible
                    ? 'orders.promotion.free_goods'.tr
                    : 'orders.promotion.badge'.tr,
                style: TextStyle(
                  color: accent,
                  fontSize: context.rsp(9.5),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                _benefitLine(context, result),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded,
            size: context.rr(16), color: colors.iconMuted),
      ],
    );
  }
}

/// State D: the ladder, compactly. Earned rungs are ticked, the next one is
/// arrowed — so a rep can see both what the depot has and what one more
/// push is worth, without reading a table.
class _TierLadder extends StatelessWidget {
  const _TierLadder({required this.result, required this.accent});

  final PromotionEvaluation result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final earned = result.earnedTier;
    final next = result.nextTier;

    // Only the rungs that matter: the one earned and the one ahead. The full
    // ladder lives in the detail sheet, where there is room to read it.
    final shown = <PromotionTier>[
      if (earned != null) earned,
      if (next != null) next,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tier in shown)
          Padding(
            padding: EdgeInsets.only(top: context.rh(2)),
            child: Row(
              children: [
                Icon(
                  tier == earned
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                  size: context.rr(11),
                  color: tier == earned ? accent : colors.textSecondary,
                ),
                SizedBox(width: context.rw(5)),
                Expanded(
                  child: Text(
                    'orders.promotion.buy_get'.trParams({
                      'qty': '${tier.minQuantity}',
                      'unit': result.promotion.unitLabel,
                      'free': '${tier.freeQuantity}',
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tier == earned
                          ? colors.textPrimary
                          : colors.textSecondary,
                      fontSize: context.rsp(10.5),
                      fontWeight:
                          tier == earned ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
