import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/active_plan_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_inventory_visibility.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_visit_plan.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_buttons.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_card_frame.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_visit_header.dart';

/// Home's "Continue visit" card for a plan the rep checked in to and has not
/// checked out of. Owns its [ActivePlanVisitCubit] and re-reads today's plans
/// on first build, each time Home is shown, and after either action.
class ContinuePlanVisitCard extends StatefulWidget {
  const ContinuePlanVisitCard({super.key, this.cubit});

  /// For tests; the card makes its own otherwise.
  final ActivePlanVisitCubit? cubit;

  @override
  State<ContinuePlanVisitCard> createState() => _ContinuePlanVisitCardState();
}

class _ContinuePlanVisitCardState extends State<ContinuePlanVisitCard> {
  late final ActivePlanVisitCubit _cubit =
      widget.cubit ?? sl<ActivePlanVisitCubit>();
  ShellTabController? _tabs;

  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<ShellTabController>()) {
      _tabs = sl<ShellTabController>()..addListener(_onTabChanged);
    }
    _cubit.refresh();
  }

  void _onTabChanged() {
    if (_tabs?.value == ShellTab.home) _cubit.refresh();
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  /// Back into the visit: the inventory photos — or, when they are already
  /// in, straight to the completion step ([startVisitPlan] checks).
  Future<void> _continue(VisitPlan plan) async {
    await startVisitPlan(context, plan, checkedIn: true);
    await _cubit.refresh();
  }

  /// Straight to the completion step and its Check out button.
  Future<void> _checkOut(VisitPlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final depotId = await resolvePlanVisitDepotId(plan);
    if (depotId == null) {
      messenger.showSnackBar(
          SnackBar(content: Text('my_visits.plans.depot_unavailable'.tr)));
      return;
    }
    if (!navigator.mounted) return;
    await openPlanVisitCompletion(
      navigator.context,
      depotId: depotId,
      depotName: plan.displayName ?? plan.depotCode ?? '',
      planId: plan.id,
    );
    await _cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivePlanVisitCubit, ActivePlanVisitState>(
      bloc: _cubit,
      builder: (context, state) {
        final plan = state.plan;
        if (plan == null) return const SizedBox.shrink();
        return ContinueVisitCardFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContinueVisitHeader(
                routeName: plan.displayName ??
                    plan.depotCode ??
                    'my_visits.plans.unnamed_outlet'.tr,
                onDismiss: _cubit.dismiss,
              ),
              SizedBox(height: context.rh(14)),
              // Check out only once the inventory photos are in: the server
              // refuses a check-out without one. Until then, Continue leads
              // to the photo step.
              ContinueVisitButtons(
                onCheckOut: state.inventoryDone ? () => _checkOut(plan) : null,
                onContinue: () => _continue(plan),
              ),
            ],
          ),
        );
      },
    );
  }
}
