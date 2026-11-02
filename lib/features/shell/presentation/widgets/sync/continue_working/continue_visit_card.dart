import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/resumable_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/ask_how_visit_ended.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/resume_workflow_dispatcher.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_buttons.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_card_frame.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_header.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_progress.dart';

/// Visit-flow "Continue Previous Work" card — styled with steel accent framing,
/// dual-bordered icon badge, and corner watermarks.
class ContinueVisitCard extends StatelessWidget {
  const ContinueVisitCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResumableVisitCubit, ResumableVisitState>(
      builder: (context, state) {
        final route = state.route;
        if (!state.loaded || route == null) return const SizedBox.shrink();
        return _VisitCard(route: route, workflow: state.workflow);
      },
    );
  }
}

/// Wires the visit card's actions to the cubit and lays out its sections.
class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.route, this.workflow});
  final RoutePlan route;
  final ActiveWorkflow? workflow;

  Future<void> _continue(BuildContext context) async {
    final cubit = context.read<ResumableVisitCubit>();
    await resumeActiveWorkflow(context, route, workflow);
    await cubit.refresh();
  }

  Future<void> _dismiss(BuildContext context) async {
    final cubit = context.read<ResumableVisitCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('sync.dismiss_checkin_title'.tr),
        content:
            Text('sync.dismiss_checkin_body'.trParams({'route': route.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.keep'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('common.dismiss'.tr,
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.dismiss();
  }

  /// The check-out sheet is the confirmation: the rep says how the visit
  /// ended, or closes it and nothing happens.
  Future<void> _checkOut(BuildContext context) async {
    final cubit = context.read<ResumableVisitCubit>();
    final decision = await askHowVisitEnded(context);
    if (decision != null) await cubit.checkOut(decision.choice);
  }

  @override
  Widget build(BuildContext context) {
    return ContinueVisitCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContinueVisitHeader(
            routeName: route.name,
            onDismiss: () => _dismiss(context),
          ),
          SizedBox(height: context.rh(10)),
          ContinueVisitProgress(
            done: route.completedStops,
            total: route.stops.length,
          ),
          SizedBox(height: context.rh(14)),
          ContinueVisitButtons(
            onCheckOut: () => _checkOut(context),
            onContinue: () => _continue(context),
          ),
        ],
      ),
    );
  }
}
