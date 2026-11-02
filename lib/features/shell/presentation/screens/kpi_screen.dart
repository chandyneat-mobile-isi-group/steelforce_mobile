import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_category_breakdown.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_filter_bar.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_incentives_section.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_metrics_grid.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_multi_select_sheet.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_pipeline_funnel.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_primary_target_card.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

// The section widgets below are deliberately not `const`: their copy reads
// `.tr` from a context-free singleton, so they must rebuild whenever this
// screen does (e.g. after a language switch) — same as when they were inline.
/// KPI tab: month/year filters, revenue target, incentives, performance grid,
/// category breakdown and pipeline funnel (sample data for now).
class KpiScreen extends StatefulWidget {
  const KpiScreen({super.key});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends State<KpiScreen> {
  // Multi-select state for Month and Year filters. Months are held as their
  // number ('1'–'12') so the selection survives a language switch; the label
  // is resolved at build time.
  List<String> _selectedMonths = ['8'];
  List<String> _selectedYears = ['2026'];

  final List<String> _allMonths = [for (var m = 1; m <= 12; m++) '$m'];

  static String _monthLabel(String month) => 'calendar.months.m$month'.tr;

  final List<String> _allYears = ['2024', '2025', '2026'];

  void _openMonthSheet() {
    showKpiMultiSelectSheet(
      context: context,
      title: 'kpi.select_month'.tr,
      options: _allMonths,
      selectedValues: _selectedMonths,
      onConfirm: (val) => setState(() => _selectedMonths = val),
      labelOf: _monthLabel,
    );
  }

  void _openYearSheet() {
    showKpiMultiSelectSheet(
      context: context,
      title: 'kpi.select_year'.tr,
      options: _allYears,
      selectedValues: _selectedYears,
      onConfirm: (val) => setState(() => _selectedYears = val),
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
            onPressed: _openMonthSheet,
          ),
          SizedBox(width: context.rw(8)),
        ],
      ),
      body: BrandWallpaperBody(
          child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(context.pagePadding),
        child: ResponsiveContentFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Month & Year Filter Dropdown Bar
              KpiFilterBar(
                monthValue: _monthFilterLabel(),
                yearValue: _yearFilterLabel(),
                onMonthTap: _openMonthSheet,
                onYearTap: _openYearSheet,
              ),
              SizedBox(height: context.rh(16)),

              // 2. Primary Target Banner
              KpiPrimaryTargetCard(),
              SizedBox(height: context.rh(16)),

              // 3. KPI Incentive Cards Section
              KpiIncentivesSection(),
              SizedBox(height: context.rh(20)),

              // 4. Section Title: Sales Performance Overview
              Text(
                'kpi.overview_heading'.tr,
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
      )),
    );
  }

  /// Display text for the month chip: the month name, or "N months".
  String _monthFilterLabel() => _selectedMonths.length == 1
      ? _monthLabel(_selectedMonths.first)
      : 'kpi.months_selected'.trParams({'count': '${_selectedMonths.length}'});

  /// Display text for the year chip: the year, or "N years".
  String _yearFilterLabel() => _selectedYears.length == 1
      ? _selectedYears.first
      : 'kpi.years_selected'.trParams({'count': '${_selectedYears.length}'});
}
