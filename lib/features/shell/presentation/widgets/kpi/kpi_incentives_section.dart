import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_incentive_card.dart';

/// Incentive cards for Payment Collection, Product Mix, Call Compliance
class KpiIncentivesSection extends StatelessWidget {
  const KpiIncentivesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KpiIncentiveCard(
          title: 'kpi.payment_collection'.tr,
          achievedText: '\$45,000',
          targetText: '/ \$50,000',
          percentage: 90,
          progress: 0.90,
          icon: Icons.payments_outlined,
        ),
        SizedBox(height: context.rh(12)),
        KpiIncentiveCard(
          title: 'kpi.product_mix'.tr,
          achievedText: 'kpi.categories_count'.trParams({'count': 7}),
          targetText: 'kpi.target_of'.trParams({'count': 10}),
          percentage: 70,
          progress: 0.70,
          icon: Icons.category_outlined,
        ),
        SizedBox(height: context.rh(12)),
        KpiIncentiveCard(
          title: 'kpi.call_compliance'.tr,
          subtitle: 'kpi.call_compliance_formula'.tr,
          achievedText: 'kpi.compliance_percent'.trParams({'percent': 0}),
          targetText: 'kpi.target_count'.trParams({'count': 0}),
          percentage: 0,
          progress: 0.0,
          icon: Icons.phone_callback_outlined,
          isCallCompliance: true,
        ),
      ],
    );
  }
}
