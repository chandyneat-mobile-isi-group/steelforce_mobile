import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';

/// Asks before throwing [visit]'s unsent steps away — they cannot be got
/// back — and discards them on yes.
Future<void> confirmPlanVisitDiscard(
  BuildContext context,
  PendingPlanVisitsCubit cubit,
  PendingPlanVisit visit,
) async {
  final shop = visit.depotName ?? 'sync_center.visit.unknown_shop'.tr;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text('sync_center.visit.discard_confirm_title'.tr),
        content: SingleChildScrollView(
          child: Text(
              'sync_center.plan.discard_confirm_body'.trParams({'shop': shop})),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('common.discard'.tr),
          ),
        ],
      );
    },
  );
  if (ok ?? false) await cubit.discard(visit.planId);
}
