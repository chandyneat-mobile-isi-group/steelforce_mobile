import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/today_visit_rules.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/depots/presentation/navigation/open_depot_by_code.dart';
import 'package:steelforce/features/depots/presentation/screens/depot_detail_screen.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/is_plan_inventory_done.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/plan_check_in_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_inventory_visibility.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stops_check_in_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_start_bar.dart';

/// A plan card tapped: the depot's details, as the Depots tab shows them.
///
/// The plans API names the depot by code; the details screen takes the
/// platform id, so the code is resolved first.
///
/// [onCheckedIn] given — the today list, where a plan can be started — puts a
/// Start Visit button at the bottom of the details screen for a plan that can
/// still start.
Future<void> openVisitPlanDepot(
  BuildContext context,
  VisitPlan plan, {
  VoidCallback? onCheckedIn,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final depotId = await resolvePlanDepotId(plan.depotCode);
  if (depotId == null) {
    messenger.showSnackBar(
        SnackBar(content: Text('my_visits.plans.depot_unavailable'.tr)));
    return;
  }
  await navigator.push(AppPageRoute<void>.sharedAxisVertical(
    settings: const RouteSettings(name: DepotDetailScreen.routeName),
    builder: (_) => DepotDetailScreen(
      depotId: depotId,
      bottomAction: onCheckedIn != null && plan.canStart
          ? VisitPlanStartBar(plan: plan, onCheckedIn: onCheckedIn)
          : null,
    ),
  ));
}

/// Start Visit on a plan card: the plan check-in, then Inventory Visibility,
/// whose photos go to the plan, then the choice of the Quotation Builder or
/// the plan's check-out. A plan already checked in goes straight to the
/// photos — or, when its photos are already in, straight on to the
/// completion screen and its Check out.
///
/// [onCheckedIn] runs once the server has the check-in, so the caller can
/// reload its lists. [checkedIn] says the caller has seen a check-in that
/// [plan], loaded earlier, does not show yet — so it is not asked for twice.
Future<void> startVisitPlan(
  BuildContext context,
  VisitPlan plan, {
  VoidCallback? onCheckedIn,
  bool checkedIn = false,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // Checked in before this call: its photos may already be in.
  final resuming = checkedIn || plan.status == VisitPlanStatus.checkedIn;

  if (!resuming) {
    // One visit at a time: another one checked in must be completed or
    // skipped first.
    if (await otherOpenVisit(plan) case final open?) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('my_visits.plans.error.visit_in_progress'.trParams(
                {'name': open.displayName ?? open.depotCode ?? ''}))));
      return;
    }
    final checkIn = await navigator.push<PlanCheckInResult>(
      AppPageRoute<PlanCheckInResult>.sharedAxisVertical(
        settings: const RouteSettings(name: VisitPlanCheckInScreen.routeName),
        // Both created here and closed with the route: the location cubit
        // is a factory, observed only while this screen is open.
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
                create: (_) =>
                    sl<PlanCheckInCubit>()..start(plan.id, locateNow: false)),
            BlocProvider(create: (_) => sl<LocationTrackingCubit>()),
          ],
          child: VisitPlanCheckInScreen(plan: plan),
        ),
      ),
    );
    if (checkIn == null) return;
    onCheckedIn?.call();
    // Offline it waits on the device; the visit carries on all the same.
    messenger.showSnackBar(SnackBar(
        content: Text((checkIn.queued
                ? 'my_visits.plans.check_in.queued'
                : 'my_visits.plans.check_in.done')
            .tr)));
  }

  final depotId = await resolvePlanVisitDepotId(plan);
  if (depotId == null) {
    messenger.showSnackBar(
        SnackBar(content: Text('my_visits.plans.depot_unavailable'.tr)));
    return;
  }
  if (!navigator.mounted) return;
  final depotName = plan.displayName ?? plan.depotCode ?? '';
  final photosIn = await planPhotosIn(plan.id, resuming: resuming);
  if (!navigator.mounted) return;
  if (photosIn) {
    // Inventory Visibility is done: on to the completion step.
    await openPlanVisitCompletion(navigator.context,
        depotId: depotId, depotName: depotName, planId: plan.id);
  } else {
    await openInventoryVisibilityForDepot(navigator.context,
        depotId: depotId, depotName: depotName, planId: plan.id);
  }
  // Again on the way out: the visit may have been checked out meanwhile.
  onCheckedIn?.call();
}

/// The depot id a plan visit's steps use. A non-depot visit has no depot
/// code: its `nonDepotId` is the Non-BP depot's own id, so its photos and
/// check-out still go to the plan.
Future<String?> resolvePlanVisitDepotId(VisitPlan plan) async {
  final nonDepotId = plan.nonDepotId?.trim() ?? '';
  return await resolvePlanDepotId(plan.depotCode) ??
      (nonDepotId.isEmpty ? null : nonDepotId);
}

/// Whether a visit being continued can skip Inventory Visibility for the
/// completion step: it was checked in before ([resuming]) and its photos are
/// sent or saved to send. A visit just checked in has none to skip.
Future<bool> planPhotosIn(String planId, {required bool resuming}) async {
  if (!resuming) return false;
  return switch (await sl<IsPlanInventoryDone>()(planId)) {
    Success(:final data) => data,
    Failed() => false,
  };
}

/// The platform id of the depot with [depotCode] — the depots feature's own
/// lookup: the rep's local book first, then the server's by-code lookup.
Future<String?> resolvePlanDepotId(String? depotCode) =>
    resolveDepotIdByCode(depotCode);
