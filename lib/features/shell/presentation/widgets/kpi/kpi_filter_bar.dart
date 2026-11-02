import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_filter_chip_button.dart';

/// Multi-select Month and Year filter bar at the top of the KPI screen: two
/// side-by-side [KpiFilterChipButton]s. The screen owns the selection state.
class KpiFilterBar extends StatelessWidget {
  const KpiFilterBar({
    super.key,
    required this.monthValue,
    required this.yearValue,
    required this.onMonthTap,
    required this.onYearTap,
  });

  /// Already-resolved display text for the current month selection.
  final String monthValue;

  /// Already-resolved display text for the current year selection.
  final String yearValue;
  final VoidCallback onMonthTap;
  final VoidCallback onYearTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: KpiFilterChipButton(
            label: 'kpi.month'.tr,
            value: monthValue,
            icon: Icons.calendar_month_outlined,
            onTap: onMonthTap,
          ),
        ),
        SizedBox(width: context.rw(12)),
        Expanded(
          child: KpiFilterChipButton(
            label: 'kpi.year'.tr,
            value: yearValue,
            icon: Icons.date_range_outlined,
            onTap: onYearTap,
          ),
        ),
      ],
    );
  }
}
