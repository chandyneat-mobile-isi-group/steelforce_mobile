import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One sales-performance stat tile: icon, growth badge, value, title and an
/// optional hint line. Used by [KpiMetricsGrid].
class KpiMetricTile extends StatelessWidget {
  const KpiMetricTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.growth,
    required this.isPositive,
    required this.icon,
  });

  final String title;
  final String? subtitle;
  final String value;
  final String growth;
  final bool isPositive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appColors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rw(12)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                size: context.rr(18),
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(6),
                    vertical: context.rh(2),
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? appColors.success : scheme.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.rr(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: context.rr(10),
                        color: isPositive ? appColors.success : scheme.error,
                      ),
                      SizedBox(width: context.rw(2)),
                      Flexible(
                        child: Text(
                          growth,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.rsp(10),
                            fontWeight: FontWeight.w700,
                            color:
                                isPositive ? appColors.success : scheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(10)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.rsp(18),
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: context.rh(4)),
          Text(
            title,
            maxLines: 2,
            softWrap: true,
            style: TextStyle(
              fontSize: context.rsp(11),
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 2,
              softWrap: true,
              style: TextStyle(
                fontSize: context.rsp(9.5),
                color: scheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}
