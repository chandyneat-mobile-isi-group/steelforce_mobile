import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Shown when the visit history list has no records. UI only — the caller
/// decides when this applies.
class VisitHistoryEmptyState extends StatelessWidget {
  const VisitHistoryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: context.rh(72),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: colors.surfaceStrong,
                  borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.map_outlined,
                  size: context.rr(34), color: primary),
            ),
            SizedBox(height: context.rh(16)),
            Text(
              'my_visits.history.empty_title'.tr,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(15),
                  fontWeight: FontWeight.w800),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              'my_visits.history.empty_subtitle'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: context.rsp(13)),
            ),
          ],
        ),
      ),
    );
  }
}
