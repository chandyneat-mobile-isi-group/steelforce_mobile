import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// Why a promotion the rep can see is not applying to this quotation, and what
/// to change to get it back.
///
/// Shown instead of dropping the card. Removing it would be less code and it is
/// what "cut it off" literally asks for, but a rep who touches the shipment
/// control and watches a 1% discount vanish has no way to know the two are
/// connected — and the most likely next move is to assume the app lost it. The
/// card stays, visibly unusable, and names the control that governs it.
class PromoBlockedNote extends StatelessWidget {
  const PromoBlockedNote({super.key, required this.requirement});

  final PromoRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final (reasonKey, hintKey) = switch (requirement) {
      PromoRequirement.pickup => (
          'promotions.blocked.pickup_only',
          'promotions.blocked.pickup_only_hint',
        ),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(10),
        vertical: context.rh(8),
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(10)),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: context.rh(1)),
            child: Icon(
              Icons.info_outline_rounded,
              size: context.rr(14),
              color: colors.iconMuted,
            ),
          ),
          SizedBox(width: context.rw(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reasonKey.tr,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(11.5),
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: context.rh(1)),
                Text(
                  hintKey.tr,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(11),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
