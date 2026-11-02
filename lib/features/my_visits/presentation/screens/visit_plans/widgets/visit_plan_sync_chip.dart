import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/plan_visit_steps_held.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plan_calendar_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plans_cubit.dart';

/// Where a visit's offline steps are: "Waiting to sync", or "Needs
/// attention" when the server refused one — tap for why, then Resend or
/// Discard. Nothing for a visit the server already has in full.
class VisitPlanSyncChip extends StatelessWidget {
  const VisitPlanSyncChip({super.key, required this.plan});

  final VisitPlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final held = plan.syncState == PlanSyncState.needsAttention;
    if (plan.syncState == PlanSyncState.synced) return const SizedBox.shrink();
    final color = held ? Theme.of(context).colorScheme.error : colors.info;
    final label = (held
            ? 'my_visits.plans.sync.needs_attention'
            : 'my_visits.plans.sync.pending')
        .tr;
    final chip = Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(8), vertical: context.rh(3)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.rr(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(held ? Icons.error_outline_rounded : Icons.cloud_upload_outlined,
              size: context.rr(13), color: color),
          SizedBox(width: context.rw(4)),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color,
                    fontSize: context.rsp(11),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (!held) return chip;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rr(8)),
        onTap: () => _showHeld(context),
        child: Padding(
          // A comfortable target around a small chip.
          padding: EdgeInsets.symmetric(vertical: context.rh(6)),
          child: chip,
        ),
      ),
    );
  }

  Future<void> _showHeld(BuildContext context) async {
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(sheet.rw(20), 0, sheet.rw(20), sheet.rh(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('my_visits.plans.sync.held_title'.tr,
                  style: Theme.of(sheet).textTheme.titleMedium),
              SizedBox(height: sheet.rh(8)),
              Text((plan.syncMessage ?? 'my_visits.plans.sync.held').tr),
              SizedBox(height: sheet.rh(8)),
              Text('my_visits.plans.sync.held_hint'.tr,
                  style: TextStyle(color: sheet.appColors.textSecondary)),
              SizedBox(height: sheet.rh(16)),
              FilledButton(
                onPressed: () => Navigator.of(sheet).pop(_Choice.resend),
                child: Text('my_visits.plans.sync.resend'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheet).pop(_Choice.discard),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(sheet).colorScheme.error),
                child: Text('my_visits.plans.sync.discard'.tr),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _Choice.discard && !await _confirmDiscard(context)) return;
    await (choice == _Choice.resend
        ? sl<ResendPlanVisitSteps>()(plan.id)
        : sl<DiscardPlanVisitSteps>()(plan.id));
    if (context.mounted) _reload(context);
  }

  Future<bool> _confirmDiscard(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('my_visits.plans.sync.discard_title'.tr),
          content: Text('my_visits.plans.sync.discard_body'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text('common.keep'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialog).colorScheme.error),
              child: Text('my_visits.plans.sync.discard'.tr),
            ),
          ],
        ),
      ) ??
      false;

  /// The lists show the change at once, wherever this card is hosted.
  static void _reload(BuildContext context) {
    try {
      context.read<VisitPlansCubit>().refresh();
      context.read<VisitPlanCalendarCubit>().load();
    } on ProviderNotFoundException {
      // Hosted outside the Visits tab: it reloads when next shown.
    }
  }
}

enum _Choice { resend, discard }
