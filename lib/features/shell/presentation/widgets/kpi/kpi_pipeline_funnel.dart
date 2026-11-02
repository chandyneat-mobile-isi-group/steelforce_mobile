import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/kpi/kpi_pipeline_step_row.dart';

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
                'kpi.leads_total'.trParams({'count': 184}),
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
