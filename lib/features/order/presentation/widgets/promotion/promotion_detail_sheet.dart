import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';

/// The full ladder, on demand.
///
/// The card carries the one rung that matters right now; this carries all of
/// them. Split that way because the two are read at different moments — the
/// card during a decision, this during a conversation ("what if I took five
/// hundred?").
///
/// Opened from the card's promotion strip. Deliberately a sheet rather than a
/// screen: a rep is mid-quotation with a depot in front of them, and a push
/// route would lose the product list behind it.
Future<void> showPromotionDetailSheet(
  BuildContext context, {
  required Promotion promotion,
  PromotionEvaluation? evaluation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PromotionDetailSheet(
      promotion: promotion,
      evaluation: evaluation,
    ),
  );
}

class _PromotionDetailSheet extends StatelessWidget {
  const _PromotionDetailSheet({required this.promotion, this.evaluation});

  final Promotion promotion;
  final PromotionEvaluation? evaluation;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final earned = evaluation?.earnedTier;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          // Never taller than two thirds: the product behind stays visible, so
          // the rep keeps their place in the list.
          maxHeight: MediaQuery.sizeOf(context).height * 0.66,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(context.rr(20))),
        ),
        padding: EdgeInsets.fromLTRB(
          context.rw(20),
          context.rh(10),
          context.rw(20),
          context.rh(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: context.rw(36),
                height: context.rh(4),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(context.rr(2)),
                ),
              ),
            ),
            SizedBox(height: context.rh(14)),
            Text(
              'orders.promotion.details_title'.tr,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Row(
              children: [
                Icon(Icons.card_giftcard_rounded,
                    size: context.rr(20), color: colors.success),
                SizedBox(width: context.rw(8)),
                Expanded(
                  child: Text(
                    context.localized(promotion.title),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(16),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (promotion.subtitle != null) ...[
              SizedBox(height: context.rh(4)),
              Text(
                context.localized(promotion.subtitle!),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(12),
                ),
              ),
            ],
            SizedBox(height: context.rh(14)),
            Text(
              'orders.promotion.qualification'.tr,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.rh(8)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final tier in promotion.tiers)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.rh(6)),
                      child: Row(
                        children: [
                          Icon(
                            tier == earned
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: context.rr(15),
                            color: tier == earned
                                ? colors.success
                                : colors.iconMuted,
                          ),
                          SizedBox(width: context.rw(8)),
                          Expanded(
                            child: Text(
                              'orders.promotion.buy_get'.trParams({
                                'qty': '${tier.minQuantity}',
                                'unit': promotion.unitLabel,
                                'free': '${tier.freeQuantity}',
                              }),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: context.rsp(13),
                                fontWeight: tier == earned
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              'orders.promotion.valid_until'
                  .trParams({'date': _formatDate(promotion.validUntil)}),
              style: TextStyle(
                color: colors.textHint,
                fontSize: context.rsp(11),
              ),
            ),
            SizedBox(height: context.rh(14)),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('orders.promotion.continue_shopping'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}
