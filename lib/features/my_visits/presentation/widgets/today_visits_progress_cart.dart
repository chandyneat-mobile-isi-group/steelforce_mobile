import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class TodayVisitProgressCard extends StatelessWidget {
  const TodayVisitProgressCard({
    super.key,
    required this.totalVisits,
    required this.visitedCount,
    required this.skippedCount,
    this.missedCount = 0,
  });

  final int totalVisits;
  final int visitedCount;
  final int skippedCount;
  final int missedCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final total = totalVisits.clamp(0, 1 << 31);
    final visited = visitedCount.clamp(0, total);
    final skipped = skippedCount.clamp(0, total - visited);
    final missed = missedCount.clamp(0, total - visited - skipped);
    final progress = total == 0 ? 0.0 : (visited + skipped + missed) / total;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rw(18)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(20)),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: total.toDouble()),
                duration: _motion(context),
                curve: AppCurves.standard,
                builder: (context, value, _) => Text(
                  value.round().toString(),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(32),
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Text(
                  'my_visits.progress_card.planned_visits'.tr,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(10),
                  vertical: context.rh(6),
                ),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.rr(20)),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: colors.success,
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(18)),
          _ProgressBar(
            visitedFraction: total == 0 ? 0 : visited / total,
            skippedFraction: total == 0 ? 0 : skipped / total,
            missedFraction: total == 0 ? 0 : missed / total,
            visitedColor: colors.success,
            skippedColor: Colors.amber.shade700,
            missedColor: Theme.of(context).colorScheme.error,
            trackColor: colors.border.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

Duration _motion(BuildContext context) =>
    (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
        ? Duration.zero
        : AppDurations.entrance;

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.visitedFraction,
    required this.skippedFraction,
    required this.missedFraction,
    required this.visitedColor,
    required this.skippedColor,
    required this.missedColor,
    required this.trackColor,
  });

  final double visitedFraction;
  final double skippedFraction;
  final double missedFraction;
  final Color visitedColor;
  final Color skippedColor;
  final Color missedColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.rr(8)),
      child: SizedBox(
        height: context.rh(9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (!width.isFinite) return ColoredBox(color: trackColor);
            Widget segment(double fraction, Color color) =>
                TweenAnimationBuilder<double>(
                  tween: Tween(end: fraction.clamp(0.0, 1.0)),
                  duration: _motion(context),
                  curve: AppCurves.standard,
                  builder: (context, value, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: width * value,
                      child: ColoredBox(color: color),
                    ),
                  ),
                );
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: trackColor),
                segment(
                  visitedFraction + skippedFraction + missedFraction,
                  missedColor,
                ),
                segment(visitedFraction + skippedFraction, skippedColor),
                segment(visitedFraction, visitedColor),
              ],
            );
          },
        ),
      ),
    );
  }
}
