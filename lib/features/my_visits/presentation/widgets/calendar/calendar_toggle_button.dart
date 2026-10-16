import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The calendar's compact header: today's date and a dot summary of today's stops.
class CalendarToggleButton extends StatelessWidget {
  const CalendarToggleButton({
    super.key,
    required this.expanded,
    required this.todayStopCount,
    required this.onTap,
    this.trailing,
  });

  final bool expanded;
  final int todayStopCount;
  final VoidCallback onTap;

  /// An action that sits beside the expand chevron — currently the map
  /// button. Outside the [InkWell] below, so tapping it does not also toggle
  /// the calendar open.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // The header is a row of two independent targets, not one: the date area
    // toggles the month view, and [trailing] does its own thing. Nesting the
    // action inside the toggle's `InkWell` made every tap on the map button
    // also expand the calendar underneath the screen it pushed.
    return Row(
      children: [
        Expanded(child: _toggle(context, colors, scheme, now)),
        if (trailing != null) ...[
          SizedBox(width: context.rw(8)),
          trailing!,
        ],
      ],
    );
  }

  Widget _toggle(BuildContext context, AppThemeColors colors,
      ColorScheme scheme, DateTime now) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.rr(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(4), vertical: context.rh(2)),
        child: Row(
          children: [
            Container(
              // FIXED: Converted width, height, and icon size to context.rr
              width: context.rr(40),
              height: context.rr(40),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.rr(12)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.calendar_today_rounded,
                color: scheme.primary,
                size: context.rr(18),
              ),
            ),
            SizedBox(width: context.rw(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(now),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.iconMuted,
                size: context.rr(24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
