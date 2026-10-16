import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class TodayVisitProgressCard extends StatelessWidget {
  const TodayVisitProgressCard({
    super.key,
    required this.totalVisits,
    required this.visitedCount,
    required this.skippedCount,
  });

  final int totalVisits;
  final int visitedCount;
  final int skippedCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final remainingCount =
        (totalVisits - visitedCount - skippedCount).clamp(0, totalVisits);
    final progressPercent = totalVisits > 0
        ? (((visitedCount + skippedCount) / totalVisits) * 100).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's visit progress",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(14),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(10),
                  vertical: context.rh(3),
                ),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.rr(12)),
                ),
                // Counts, rather than jumping. This badge and the bar below
                // are the only acknowledgement a rep gets that a completed
                // visit registered — `WatchAllRoutes` pushes the new counts in
                // from the database the instant the check-out lands, and a
                // number that simply changes between two frames is a number
                // nobody sees change.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progressPercent.toDouble()),
                  duration: _motion(context),
                  curve: AppCurves.standard,
                  builder: (context, value, _) => Text(
                    '${value.round()}%',
                    style: TextStyle(
                      color: colors.success,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),

          // Multi-segment progress bar
          _ProgressBar(
            visitedFraction: totalVisits > 0 ? visitedCount / totalVisits : 0,
            skippedFraction: totalVisits > 0 ? skippedCount / totalVisits : 0,
            visitedColor: colors.success,
            skippedColor: Colors.amber,
            trackColor: colors.border.withValues(alpha: 0.5),
          ),
          SizedBox(height: context.rh(12)),

          // Legends
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(
                color: colors.success,
                label: '$visitedCount In Plan',
              ),
              _LegendItem(
                color: Colors.amber,
                label: '$skippedCount skipped',
              ),
              _LegendItem(
                color: colors.textSecondary,
                label: '$remainingCount Remaining',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reduce-motion aware duration for this card's two animations.
///
/// FS-ANI-7: a rep who has asked the OS for less motion gets the final value
/// on the first frame, and widget tests stay deterministic without pumping.
Duration _motion(BuildContext context) =>
    (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
        ? Duration.zero
        : AppDurations.entrance;

/// The three-segment progress track.
///
/// Widths rather than `Expanded(flex:)`. Flex is an `int`, so the old version
/// could only ever step between whole visits — one completed stop on a
/// six-stop route moved the bar in a single frame. Fractions tween, so the
/// bar grows into its new length.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.visitedFraction,
    required this.skippedFraction,
    required this.visitedColor,
    required this.skippedColor,
    required this.trackColor,
  });

  final double visitedFraction;
  final double skippedFraction;
  final Color visitedColor;
  final Color skippedColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.rr(6)),
      child: SizedBox(
        height: context.rh(8),
        // Painted back-to-front: the grey track fills the bar, then skipped,
        // then visited on top. One tween per segment would leave a hairline
        // gap between them mid-animation; overlaying cannot.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Guard against an unbounded parent: `double.infinity * 0.5` is
            // infinity, and an infinite width is a layout crash, not a wide
            // bar.
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.rr(8),
          height: context.rr(8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: context.rw(6)),
        Text(
          label,
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: context.rsp(11.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
