import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Three short reminders for a useful stock photo.
class InventoryPhotoTips extends StatelessWidget {
  const InventoryPhotoTips({super.key});

  static const _tips = [
    'my_visits.survey.tip_light',
    'my_visits.survey.tip_stock',
    'my_visits.survey.tip_angles',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              color: scheme.primary, size: context.rr(26)),
          SizedBox(width: context.rw(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('my_visits.survey.tips_title'.tr,
                    style: TextStyle(
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
                for (final tip in _tips)
                  Padding(
                    padding: EdgeInsets.only(top: context.rh(6)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_rounded,
                            color: colors.success, size: context.rr(18)),
                        SizedBox(width: context.rw(8)),
                        Expanded(
                          child: Text(tip.tr,
                              style: TextStyle(
                                  fontSize: context.rsp(12.5),
                                  color: colors.textSecondary)),
                        ),
                      ],
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
