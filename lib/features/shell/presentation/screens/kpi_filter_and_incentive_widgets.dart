import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Filter chip button widget
class KpiFilterChipButton extends StatelessWidget {
  const KpiFilterChipButton({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.rr(12)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(12),
          vertical: context.rh(10),
        ),
        decoration: BoxDecoration(
          color: appColors.surfaceSoft,
          borderRadius: BorderRadius.circular(context.rr(12)),
          border: Border.all(color: appColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: context.rr(16), color: scheme.primary),
                SizedBox(width: context.rw(8)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: context.rsp(13),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: context.rr(18),
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Incentive Card for Payment Collection, Product Mix, Call Compliance
class KpiIncentiveCard extends StatelessWidget {
  const KpiIncentiveCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.achievedText,
    required this.targetText,
    required this.percentage,
    required this.progress,
    required this.icon,
    this.isCallCompliance = false,
  });

  final String title;
  final String? subtitle;
  final String achievedText;
  final String targetText;
  final int percentage;
  final double progress;
  final IconData icon;
  final bool isCallCompliance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rw(14)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: context.rr(18),
                      color: scheme.primary,
                    ),
                    SizedBox(width: context.rw(8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: context.rsp(10),
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCallCompliance)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(8),
                    vertical: context.rh(2),
                  ),
                  decoration: BoxDecoration(
                    color: appColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.rr(12)),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w800,
                      color: appColors.success,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: context.rh(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                achievedText,
                style: TextStyle(
                  fontSize:
                      isCallCompliance ? context.rsp(11) : context.rsp(16),
                  fontWeight: FontWeight.w800,
                  color: isCallCompliance
                      ? scheme.onSurface.withValues(alpha: 0.5)
                      : scheme.onSurface,
                ),
              ),
              Text(
                targetText,
                style: TextStyle(
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          Stack(
            children: [
              Container(
                height: context.rh(8),
                decoration: BoxDecoration(
                  color: appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(context.rr(8)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: context.rh(8),
                  decoration: BoxDecoration(
                    color: appColors.success,
                    borderRadius: BorderRadius.circular(context.rr(8)),
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
