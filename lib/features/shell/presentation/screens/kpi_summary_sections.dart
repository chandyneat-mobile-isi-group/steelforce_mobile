import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_filter_and_incentive_widgets.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_in_visit_vs_ad_hoc_card.dart';
import 'package:steelforce/features/shell/presentation/screens/kpi_metric_widgets.dart';

/// Revenue target banner: achieved vs target with a progress bar.
class KpiPrimaryTargetCard extends StatelessWidget {
  const KpiPrimaryTargetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appColors = context.appColors;

    const double target = 150000;
    const double achieved = 122400;
    final progress = (achieved / target).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return Container(
      padding: EdgeInsets.all(context.rw(18)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(20)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.25 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.rw(8)),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(context.rr(10)),
                      ),
                      child: Icon(
                        Icons.stars_rounded,
                        size: context.rr(18),
                        color: scheme.primary,
                      ),
                    ),
                    SizedBox(width: context.rw(10)),
                    Flexible(
                      child: Text(
                        'kpi.revenue_target'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.rsp(14),
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.rw(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(10),
                  vertical: context.rh(4),
                ),
                decoration: BoxDecoration(
                  color: appColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.rr(20)),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w800,
                    color: appColors.success,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(16)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '\$${achieved.toInt()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(24),
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              SizedBox(width: context.rw(6)),
              Flexible(
                child: Text(
                  '/ \$${target.toInt()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),
          Stack(
            children: [
              Container(
                height: context.rh(10),
                decoration: BoxDecoration(
                  color: appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(context.rr(10)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: context.rh(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        appColors.success.withValues(alpha: 0.8),
                        appColors.success,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Incentive cards for Payment Collection, Product Mix, Call Compliance
class KpiIncentivesSection extends StatelessWidget {
  const KpiIncentivesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KpiIncentiveCard(
          title: 'Payment Collection',
          achievedText: '\$45,000',
          targetText: '/ \$50,000',
          percentage: 90,
          progress: 0.90,
          icon: Icons.payments_outlined,
        ),
        SizedBox(height: context.rh(12)),
        KpiIncentiveCard(
          title: 'Product Mix',
          achievedText: '7 Categories',
          targetText: '/ 10 Target',
          percentage: 70,
          progress: 0.70,
          icon: Icons.category_outlined,
        ),
        SizedBox(height: context.rh(12)),
        KpiIncentiveCard(
          title: 'Call Compliance',
          subtitle: 'Visited / (Target - Skipped)',
          achievedText: '0% COMPLIANCE',
          targetText: 'Target 0',
          percentage: 0,
          progress: 0.0,
          icon: Icons.phone_callback_outlined,
          isCallCompliance: true,
        ),
      ],
    );
  }
}

/// Grid containing the 4 standard tiles in 2 columns + full-width Order Breakdown card
class KpiMetricsGrid extends StatelessWidget {
  const KpiMetricsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(
              child: KpiMetricTile(
                title: '# of Active Outlets',
                subtitle: 'PO within 3 months',
                value: '124',
                growth: '+8.2%',
                isPositive: true,
                icon: Icons.store_outlined,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: KpiMetricTile(
                title: '# of Inactive Outlets',
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
          children: const [
            Expanded(
              child: KpiMetricTile(
                title: '# of ASO',
                value: '12',
                growth: '0.0%',
                isPositive: true,
                icon: Icons.badge_outlined,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: KpiMetricTile(
                title: 'Conversion Rate',
                subtitle: 'Strike Rate',
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

/// Revenue split by product category.
class KpiCategoryBreakdown extends StatelessWidget {
  const KpiCategoryBreakdown({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(20)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'kpi.category_breakdown'.tr,
            style: TextStyle(
              fontSize: context.rsp(15),
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: context.rh(16)),
          KpiCategoryProgressRow(
            title: 'ISI Roofing & Cladding',
            amount: '\$68,400',
            progress: 0.85,
            color: scheme.primary,
          ),
          SizedBox(height: context.rh(14)),
          KpiCategoryProgressRow(
            title: 'ISI Structural Steel',
            amount: '\$34,200',
            progress: 0.60,
            color: appColors.success,
          ),
          SizedBox(height: context.rh(14)),
          KpiCategoryProgressRow(
            title: 'ISI Decking & Pipes',
            amount: '\$19,800',
            progress: 0.45,
            color: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }
}

/// Lead pipeline funnel, stage by stage.
class KpiPipelineFunnel extends StatelessWidget {
  const KpiPipelineFunnel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(20)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'kpi.pipeline_funnel'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(15),
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              SizedBox(width: context.rw(8)),
              Text(
                '184 Leads',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.rsp(12),
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(16)),
          KpiPipelineStepRow(
              stage: 'kpi.stage_leads'.tr, count: '184', percent: '100%'),
          KpiPipelineStepRow(
              stage: 'kpi.stage_contacted'.tr, count: '112', percent: '60%'),
          KpiPipelineStepRow(
              stage: 'kpi.stage_quotation'.tr, count: '64', percent: '34%'),
          KpiPipelineStepRow(
              stage: 'kpi.stage_won'.tr,
              count: '42',
              percent: '22%',
              isLast: true),
        ],
      ),
    );
  }
}
