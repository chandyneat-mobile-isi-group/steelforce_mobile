import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/plan_visit_discard_dialog.dart';

/// **Discard**, and **Send again** for a visit the server refused — on its
/// Sync Center card and in its details. Sending otherwise is automatic, and
/// the Center's own **Sync Now**.
class PlanVisitActions extends StatelessWidget {
  const PlanVisitActions({super.key, required this.visit, required this.busy});

  final PendingPlanVisit visit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PendingPlanVisitsCubit>();
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: context.rw(4),
      children: [
        TextButton(
          onPressed: busy
              ? null
              : () => confirmPlanVisitDiscard(context, cubit, visit),
          child: Text(
            'common.discard'.tr,
            style: TextStyle(color: busy ? null : scheme.error),
          ),
        ),
        if (visit.needsAttention)
          FilledButton.tonalIcon(
            onPressed: busy ? null : () => cubit.resend(visit.planId),
            icon: Icon(Icons.refresh_rounded, size: context.rr(16)),
            label: Text('sync_center.plan.send_again'.tr),
          ),
      ],
    );
  }
}
