import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_in_visit_vs_ad_hoc_card.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_metric_tile.dart';

/// Grid containing the 4 standard tiles in 2 columns + full-width Order Breakdown card
class KpiMetricsGrid extends StatelessWidget {
  const KpiMetricsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiMetricTile(
                title: 'kpi.active_outlets'.tr,
                subtitle: 'kpi.active_outlets_hint'.tr,
                value: '124',
                growth: '+8.2%',
                isPositive: true,
                icon: Icons.store_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiMetricTile(
                title: 'kpi.inactive_outlets'.tr,
                value: '18',
                growth: '-2.1%',
                isPositive: true,
                icon: Icons.storefront_outlined,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(12)),
        Row(
          children: [
            Expanded(
              child: KpiMetricTile(
                title: 'kpi.aso_count'.tr,
                value: '12',
                growth: '0.0%',
                isPositive: true,
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiMetricTile(
                title: 'kpi.conversion_rate'.tr,
                subtitle: 'kpi.strike_rate'.tr,
                value: '34.8%',
                growth: '+3.1%',
                isPositive: true,
                icon: Icons.pie_chart_outline_rounded,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(12)),
        // In-visit vs Ad-hoc Orders Detailed Card
        const KpiInVisitVsAdHocCard(
          totalOrders: 74,
          inVisitCount: 9,
          inVisitPercentage: 12,
          adHocCount: 65,
          adHocPercentage: 88,
        ),
      ],
    );
  }
}
