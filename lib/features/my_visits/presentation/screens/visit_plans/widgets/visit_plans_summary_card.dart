import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// The day's progress, exactly as the server counted it: a ring for the
/// share completed, then completed, remaining, skipped and missed — and ad
/// hoc when the response carries it.
///
/// The ring fills and the numbers count up whenever the counts change; with
/// reduced motion on they simply appear.
class VisitPlansSummaryCard extends StatelessWidget {
  const VisitPlansSummaryCard({super.key, required this.overview});

  final VisitPlansOverview overview;

  static const _duration = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    String label(String key) => 'my_visits.plans.summary.$key'.tr;
    final done = overview.total == 0
        ? 0.0
        : (overview.completed / overview.total).clamp(0.0, 1.0);
    final duration =
        MediaQuery.of(context).disableAnimations ? Duration.zero : _duration;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(20)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProgressRing(
                value: done,
                duration: duration,
                color: colors.success,
                track: colors.border,
                semanticsLabel: label('progress'),
              ),
              SizedBox(width: context.rw(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label('completed_of').trParams({
                        'done': '${overview.completed}',
                        'total': '${overview.total}',
                      }),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(16),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    Text(
                      label('total'),
                      style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: context.rsp(12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(14)),
          Row(
            children: [
              for (final (i, stat) in [
                (overview.completed, label('completed'), colors.success),
                (overview.remaining, label('remaining'), colors.info),
                (overview.skipped, label('skipped'), colors.slate),
                (overview.missed, label('missed'), scheme.error),
              ].indexed) ...[
                if (i > 0) SizedBox(width: context.rw(8)),
                Expanded(
                  child: _StatTile(
                    value: stat.$1,
                    label: stat.$2,
                    color: stat.$3,
                    duration: duration,
                  ),
                ),
              ],
            ],
          ),
          if (overview.adHoc != null) ...[
            SizedBox(height: context.rh(10)),
            Text(
              label('ad_hoc').trParams({'count': '${overview.adHoc}'}),
              style: TextStyle(
                  color: colors.textSecondary, fontSize: context.rsp(12)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A ring that fills to [value], the percentage in its middle.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.duration,
    required this.color,
    required this.track,
    required this.semanticsLabel,
  });

  final double value;
  final Duration duration;
  final Color color;
  final Color track;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final size = context.rr(64);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: shown,
                strokeWidth: context.rr(7),
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: track,
                // A number, as screen readers require: the percentage.
                semanticsLabel: semanticsLabel,
                semanticsValue: '${(value * 100).round()}',
              ),
            ),
            Text(
              '${(shown * 100).round()}%',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One count on a soft tint of its colour; the number counts up to [value].
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.duration,
  });

  final int value;
  final String label;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(8), vertical: context.rh(10)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(context.rr(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, shown, _) => Text(
              '$shown',
              style: TextStyle(
                color: color,
                fontSize: context.rsp(20),
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          SizedBox(height: context.rh(2)),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: context.rsp(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
