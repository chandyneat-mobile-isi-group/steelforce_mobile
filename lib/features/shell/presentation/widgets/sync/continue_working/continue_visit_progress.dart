import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// "N of M checked in" label, brand-blue percentage, and progress bar on the
/// "Continue visit" card. The bar is hidden when the route has no stops.
class ContinueVisitProgress extends StatelessWidget {
  const ContinueVisitProgress({
    super.key,
    required this.done,
    required this.total,
  });
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'sync.checkin_progress'.trParams({'done': done, 'total': total}),
              style: TextStyle(
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            Text(
              '${((total > 0 ? done / total : 0) * 100).toInt()}%',
              style: TextStyle(
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(6)),
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(context.rr(4)),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: context.rh(6),
              backgroundColor: colors.border.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
      ],
    );
  }
}
