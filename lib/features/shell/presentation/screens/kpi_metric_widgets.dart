import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

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

class KpiCategoryProgressRow extends StatelessWidget {
  const KpiCategoryProgressRow({
    super.key,
    required this.title,
    required this.amount,
    required this.progress,
    required this.color,
  });

  final String title;
  final String amount;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.rsp(13),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(width: context.rw(8)),
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: context.rsp(13),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(6)),
        Stack(
          children: [
            Container(
              height: context.rh(6),
              decoration: BoxDecoration(
                color: appColors.surfaceSoft,
                borderRadius: BorderRadius.circular(context.rr(6)),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: context.rh(6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(context.rr(6)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class KpiPipelineStepRow extends StatelessWidget {
  const KpiPipelineStepRow({
    super.key,
    required this.stage,
    required this.count,
    required this.percent,
    this.isLast = false,
  });

  final String stage;
  final String count;
  final String percent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : context.rh(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              stage,
              maxLines: 2,
              softWrap: true,
              style: TextStyle(
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          SizedBox(width: context.rw(10)),
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rw(10),
                vertical: context.rh(6),
              ),
              decoration: BoxDecoration(
                color: appColors.surfaceSoft,
                borderRadius: BorderRadius.circular(context.rr(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$count leads',
                    style: TextStyle(
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    percent,
                    style: TextStyle(
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
