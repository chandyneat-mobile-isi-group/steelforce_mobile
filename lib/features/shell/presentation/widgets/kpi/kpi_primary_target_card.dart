import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Revenue target banner: achieved vs target with a progress bar.
class KpiPrimaryTargetCard extends StatelessWidget {
  const KpiPrimaryTargetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appColors = context.appColors;

    const double target = 150000;
    const double achieved = 122400;
    final progress = (achieved / target).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return Container(
      padding: EdgeInsets.all(context.rw(18)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(20)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.25 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.rw(8)),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(context.rr(10)),
                      ),
                      child: Icon(
                        Icons.stars_rounded,
                        size: context.rr(18),
                        color: scheme.primary,
                      ),
                    ),
                    SizedBox(width: context.rw(10)),
                    Flexible(
                      child: Text(
                        'kpi.revenue_target'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.rsp(14),
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.rw(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(10),
                  vertical: context.rh(4),
                ),
                decoration: BoxDecoration(
                  color: appColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.rr(20)),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w800,
                    color: appColors.success,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(16)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '\$${achieved.toInt()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(24),
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              SizedBox(width: context.rw(6)),
              Flexible(
                child: Text(
                  '/ \$${target.toInt()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),
          Stack(
            children: [
              Container(
                height: context.rh(10),
                decoration: BoxDecoration(
                  color: appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(context.rr(10)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: context.rh(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        appColors.success.withValues(alpha: 0.8),
                        appColors.success,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
