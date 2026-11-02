import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_category_progress_row.dart';

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
