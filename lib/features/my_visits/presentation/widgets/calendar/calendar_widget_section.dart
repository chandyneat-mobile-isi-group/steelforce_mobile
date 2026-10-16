import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:steelforce/core/localization/localization_services.dart';

import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/calendar/calendar_month_view.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/calendar/calendar_toggle_button.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Compact-by-default, expandable monthly stop calendar for the My Visit Dashboard.
class StopCalendarSection extends StatefulWidget {
  const StopCalendarSection({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.stopCountForDate,
    this.initiallyExpanded = false,
    this.onOpenMap,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  /// Number of stops scheduled on [date].
  final int Function(DateTime date) stopCountForDate;

  final bool initiallyExpanded;

  /// Opens the full-screen map of the selected day's stops. Null hides the
  /// button — there is nothing to plot before the stops have loaded.
  final VoidCallback? onOpenMap;

  @override
  State<StopCalendarSection> createState() => _StopCalendarSectionState();
}

class _StopCalendarSectionState extends State<StopCalendarSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final today = DateTime.now();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(14),
        vertical: context.rh(14),
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(18)),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CalendarToggleButton(
            expanded: _expanded,
            todayStopCount: widget.stopCountForDate(today),
            onTap: () => setState(() => _expanded = !_expanded),
            trailing: widget.onOpenMap == null
                ? null
                : _MapButton(onTap: widget.onOpenMap!),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      key: const ValueKey('calendar-expanded'),
                      padding: EdgeInsets.only(top: context.rh(16)),
                      child: CalendarMonthView(
                        focusedMonth: widget.focusedMonth,
                        selectedDate: widget.selectedDate,
                        onMonthChanged: widget.onMonthChanged,
                        onDateSelected: widget.onDateSelected,
                        stopCountForDate: widget.stopCountForDate,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('calendar-collapsed'),
                      width: double.infinity,
                      height: 0,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The map affordance beside the calendar header.
///
/// Sized to the 48dp minimum target rather than the icon: a rep taps this
/// standing in a yard, often one-handed, and a 24dp hit box is a miss.
class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      // The icon carries no text, so the label is the only thing a screen
      // reader has to work with.
      label: 'my_visits.stops_map.open'.tr,
      child: Tooltip(
        message: 'my_visits.stops_map.open'.tr,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(context.rr(12)),
          child: Container(
            width: context.rr(44),
            height: context.rr(44),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.rr(12)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.map_rounded,
              color: scheme.primary,
              size: context.rr(20),
            ),
          ),
        ),
      ),
    );
  }
}
