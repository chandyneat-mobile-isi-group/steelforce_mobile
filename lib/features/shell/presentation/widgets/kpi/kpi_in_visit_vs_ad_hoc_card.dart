import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_order_channel_stat.dart';

/// Ad-hoc order accent (bar segment + icon). No matching theme token exists
/// yet, so it is held here once rather than repeated inline.
const Color _adHocColor = Color(0xFF5B4EFF);

/// "In-visit vs Ad-hoc" orders card on the KPI screen: total orders, a
/// segmented split bar and the two per-channel stats.
/// (New Component matching the exact design from the reference image.)
class KpiInVisitVsAdHocCard extends StatelessWidget {
  const KpiInVisitVsAdHocCard({
    super.key,
    required this.totalOrders,
    required this.inVisitCount,
    required this.inVisitPercentage,
    required this.adHocCount,
    required this.adHocPercentage,
  });

  final int totalOrders;
  final int inVisitCount;
  final int inVisitPercentage;
  final int adHocCount;
  final int adHocPercentage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'kpi.in_visit_vs_ad_hoc'.tr,
            style: TextStyle(
              fontSize: context.rsp(14),
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: context.rh(8)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$totalOrders',
                style: TextStyle(
                  fontSize: context.rsp(20),
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(width: context.rw(6)),
              Text(
                'kpi.total_orders'.tr.toUpperCase(),
                style: TextStyle(
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),
          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(context.rr(6)),
            child: SizedBox(
              height: context.rh(8),
              child: Row(
                children: [
                  Expanded(
                    flex: inVisitPercentage,
                    child: Container(color: Colors.green.shade600),
                  ),
                  SizedBox(width: context.rw(4)),
                  Expanded(
                    flex: adHocPercentage,
                    child: Container(color: _adHocColor),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.rh(14)),
          // Sub-metrics Box
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(12),
              vertical: context.rh(10),
            ),
            decoration: BoxDecoration(
              color: appColors.surfaceSoft,
              borderRadius: BorderRadius.circular(context.rr(12)),
            ),
            child: Row(
              children: [
                // In-visit Column
                Expanded(
                  child: KpiOrderChannelStat(
                    icon: Icons.arrow_forward_rounded,
                    iconColor: Colors.green.shade700,
                    count: inVisitCount,
                    percentage: inVisitPercentage,
                    label: 'kpi.in_visit'.tr,
                  ),
                ),
                Container(
                  height: context.rh(28),
                  width: 1,
                  color: scheme.onSurface.withValues(alpha: 0.12),
                ),
                SizedBox(width: context.rw(12)),
                // Ad-hoc Column
                Expanded(
                  child: KpiOrderChannelStat(
                    icon: Icons.exit_to_app_rounded,
                    iconColor: _adHocColor,
                    count: adHocCount,
                    percentage: adHocPercentage,
                    label: 'kpi.ad_hoc'.tr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
