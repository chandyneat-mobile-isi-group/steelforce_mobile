import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'calendar_day_cell.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.stopCountForDate,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final int Function(DateTime date) stopCountForDate;

  void _goToMonth(int offset) {
    onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month + offset, 1));
  }

  /// Filter out Sunday dates for Mon-Sat display grid
  List<DateTime> _generateMonToSatDates(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);

    // Find nearest preceding Monday
    int leadingDays = firstOfMonth.weekday - DateTime.monday;
    if (leadingDays < 0) leadingDays += 7;

    final gridStart = firstOfMonth.subtract(Duration(days: leadingDays));
    final List<DateTime> dates = [];

    DateTime current = gridStart;
    while (dates.length < 36) {
      // 6 weeks * 6 days (Mon-Sat)
      if (current.weekday != DateTime.sunday) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    final monthDates = _generateMonToSatDates(focusedMonth);

    const weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => _goToMonth(-1),
            ),
            Text(
              DateFormat.yMMMM().format(focusedMonth),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(16),
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _goToMonth(1),
            ),
          ],
        ),
        SizedBox(height: context.rh(12)),
        // Mon - Sat Row Header (6 Columns)
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: context.rh(8)),
        GridView.builder(
          key: ValueKey('${focusedMonth.year}-${focusedMonth.month}'),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: monthDates.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6, // 6 Days (Mon to Sat)
            mainAxisSpacing: context.rh(6),
            crossAxisSpacing: context.rw(4),
            childAspectRatio: 0.8, // Enlarge day cells
          ),
          itemBuilder: (context, index) {
            final date = monthDates[index];
            final isCurrentMonth = date.month == focusedMonth.month;
            final isToday = DateUtils.isSameDay(date, now);
            final isSelected = DateUtils.isSameDay(date, selectedDate);
            return CalendarDayCell(
              date: date,
              isCurrentMonth: isCurrentMonth,
              isToday: isToday,
              isSelected: isSelected,
              stopCount: isCurrentMonth ? stopCountForDate(date) : 0,
              onTap: () => onDateSelected(date),
            );
          },
        ),
      ],
    );
  }
}
