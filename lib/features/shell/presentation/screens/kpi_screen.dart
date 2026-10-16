import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_filter_and_incentive_widgets.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_multi_select_sheet.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_summary_sections.dart';

// The section widgets below are deliberately not `const`: their copy reads
// `.tr` from a context-free singleton, so they must rebuild whenever this
// screen does (e.g. after a language switch) — same as when they were inline.
class KpiScreen extends StatefulWidget {
  const KpiScreen({super.key});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends State<KpiScreen> {
  // Multi-select state for Month and Year filters
  List<String> _selectedMonths = ['August'];
  List<String> _selectedYears = ['2026'];

  final List<String> _allMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  final List<String> _allYears = ['2024', '2025', '2026'];

  void _openMultiSelectSheet({
    required String title,
    required List<String> options,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onConfirm,
  }) {
    showKpiMultiSelectSheet(
      context: context,
      title: title,
      options: options,
      selectedValues: selectedValues,
      onConfirm: onConfirm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompact = context.responsive(
      compact: true,
      medium: false,
      expanded: false,
    );

    return Scaffold(
      // The shell's canvas, matching Home and the other tabs.
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(
        title: Text(
          'kpi.title'.tr,
          style: TextStyle(
            fontSize: context.rsp(18),
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: context.appColors.canvas,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: scheme.onSurface,
              size: context.rr(20),
            ),
            onPressed: () {
              _openMultiSelectSheet(
                title: 'Month',
                options: _allMonths,
                selectedValues: _selectedMonths,
                onConfirm: (val) => setState(() => _selectedMonths = val),
              );
            },
          ),
          SizedBox(width: context.rw(8)),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(context.pagePadding),
        child: ResponsiveContentFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Month & Year Filter Dropdown Bar
              _buildFilterDropdownBar(),
              SizedBox(height: context.rh(16)),

              // 2. Primary Target Banner
              KpiPrimaryTargetCard(),
              SizedBox(height: context.rh(16)),

              // 3. KPI Incentive Cards Section
              KpiIncentivesSection(),
              SizedBox(height: context.rh(20)),

              // 4. Section Title: Sales Performance Overview
              Text(
                'Sales Performance Overview',
                style: TextStyle(
                  fontSize: context.rsp(16),
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: context.rh(12)),

              // 5. Sales Performance Metrics Grid (2 columns top, full width bottom)
              KpiMetricsGrid(),
              SizedBox(height: context.rh(24)),

              // 6. Product Category & Pipeline
              if (isCompact) ...[
                KpiCategoryBreakdown(),
                SizedBox(height: context.rh(24)),
                KpiPipelineFunnel(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: KpiCategoryBreakdown(),
                    ),
                    SizedBox(width: context.rw(16)),
                    Expanded(
                      child: KpiPipelineFunnel(),
                    ),
                  ],
                ),
              ],
              SizedBox(height: context.rh(24)),
            ],
          ),
        ),
      ),
    );
  }

  /// Multi-select Month and Year Filter Bar
  Widget _buildFilterDropdownBar() {
    final monthLabel = _selectedMonths.length == 1
        ? _selectedMonths.first
        : '${_selectedMonths.length} Months';
    final yearLabel = _selectedYears.length == 1
        ? _selectedYears.first
        : '${_selectedYears.length} Years';

    return Row(
      children: [
        Expanded(
          child: KpiFilterChipButton(
            label: 'Month',
            value: monthLabel,
            icon: Icons.calendar_month_outlined,
            onTap: () {
              _openMultiSelectSheet(
                title: 'Month',
                options: _allMonths,
                selectedValues: _selectedMonths,
                onConfirm: (val) => setState(() => _selectedMonths = val),
              );
            },
          ),
        ),
        SizedBox(width: context.rw(12)),
        Expanded(
          child: KpiFilterChipButton(
            label: 'Year',
            value: yearLabel,
            icon: Icons.date_range_outlined,
            onTap: () {
              _openMultiSelectSheet(
                title: 'Year',
                options: _allYears,
                selectedValues: _selectedYears,
                onConfirm: (val) => setState(() => _selectedYears = val),
              );
            },
          ),
        ),
      ],
    );
  }
}
