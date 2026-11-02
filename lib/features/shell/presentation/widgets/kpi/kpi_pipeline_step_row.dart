import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One stage row of the lead pipeline funnel ([KpiPipelineFunnel]): stage
/// name, lead count and conversion percent.
class KpiPipelineStepRow extends StatelessWidget {
  const KpiPipelineStepRow({
    super.key,
    required this.stage,
    required this.count,
    required this.percent,
    this.isLast = false,
  });

  final String stage;
  final String count;
  final String percent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : context.rh(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              stage,
              maxLines: 2,
              softWrap: true,
              style: TextStyle(
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          SizedBox(width: context.rw(10)),
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rw(10),
                vertical: context.rh(6),
              ),
              decoration: BoxDecoration(
                color: appColors.surfaceSoft,
                borderRadius: BorderRadius.circular(context.rr(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'kpi.stage_leads_count'.trParams({'count': count}),
                    style: TextStyle(
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    percent,
                    style: TextStyle(
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
