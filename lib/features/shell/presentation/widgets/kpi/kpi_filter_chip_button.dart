import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Tappable month/year filter chip on the KPI screen: icon, current value and
/// a dropdown chevron. Opens the multi-select sheet via [onTap].
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
