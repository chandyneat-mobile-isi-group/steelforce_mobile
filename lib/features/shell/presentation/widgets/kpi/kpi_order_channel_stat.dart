import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// One half of the [KpiInVisitVsAdHocCard] sub-metrics box: a white circular
/// icon, the order count with a % pill, and the channel label underneath.
class KpiOrderChannelStat extends StatelessWidget {
  const KpiOrderChannelStat({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.percentage,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final int count;
  final int percentage;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(context.rw(6)),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: context.rr(14),
            color: iconColor,
          ),
        ),
        SizedBox(width: context.rw(8)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(width: context.rw(4)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(6),
                    vertical: context.rh(2),
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      context.rr(10),
                    ),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: context.rsp(10),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: context.rsp(11),
                fontWeight: FontWeight.w500,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
