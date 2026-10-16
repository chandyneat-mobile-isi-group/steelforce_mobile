import 'dart:async';

import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/clear_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/save_active_workflow.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';

/// Keeps the "Continue Working" resume pointer in step with the route.
///
/// Fire-and-forget upsert — advisory (stop status in the DB is the real source
/// of truth on resume), so a slow/failed write here never blocks the UI.
///
/// When the current stop is checked in, the pointer is enriched into a
/// *workflow-aware* row: Shop/Depot + check-in time + a baseline
/// [VisitWorkflow.stockCount] (the guided step that immediately follows
/// check-in) + the navigation arguments the resume dispatcher needs to
/// rebuild the exact screen. Business-task transitions (Quotation/Sales Order)
/// layer onto this via `UpdateWorkflowStep`. When the stop is not checked in
/// (before check-in or after check-out), the workflow fields are cleared so
/// resume falls back to the guided route flow.
class WorkflowPointerWriter {
  const WorkflowPointerWriter({
    required SaveActiveWorkflow save,
    required ClearActiveWorkflow clear,
    required GetActiveWorkflow get,
  })  : _save = save,
        _clear = clear,
        _get = get;

  final SaveActiveWorkflow _save;
  final ClearActiveWorkflow _clear;
  final GetActiveWorkflow _get;

  void persist(ActiveRouteReady state) {
    // Gated on `dayStarted` alone, this silently refused to write the pointer
    // for a stop that was genuinely checked in — the same class of silent
    // block `ActiveRouteBloc._onGeofenceChanged` documents.
    //
    // Entering through Stop Dashboard -> Stop Information -> Check-in loads
    // the route fresh, so before the fix in `_onLoad` the flag was always down
    // here. The check-in succeeded and pushed, but no workflow row was
    // written, so `CompleteVisitCheckOut` had nothing to close: it logged
    // `visit.checkout.skipped reason=noActiveWorkflow`, wrote no check-out and
    // no status update, and the stop card sat on "In Progress" forever.
    //
    // A checked-in stop *is* a live visit whatever the day flag says, and a
    // visit that cannot be resumed is a visit that cannot be completed.
    final stop =
        state.hasCurrentStop ? state.route.stops[state.currentStopIndex] : null;
    if (!state.dayStarted && stop?.status != VisitStatus.checkedIn) return;
    unawaited(_write(state));
  }

  Future<void> _write(ActiveRouteReady state) async {
    final stop =
        state.hasCurrentStop ? state.route.stops[state.currentStopIndex] : null;
    final isActive = stop != null && stop.status == VisitStatus.checkedIn;
    final now = DateTime.now();

    if (!isActive) {
      // Only drop the pointer when there is no live visit left anywhere on the
      // route. Merely *selecting* a different stop while one is still checked
      // in used to clear it, which is the other way a visit became impossible
      // to close: the check-out found no workflow and skipped, leaving the
      // stop on "In Progress" with no way back into it.
      final hasLiveVisit =
          state.route.stops.any((s) => s.status == VisitStatus.checkedIn);
      if (!hasLiveVisit) await _clear(const NoParams());
      return;
    }

    // Baseline for a live visit: the guided Stock Count step, which now sits
    // between check-in and the Quotation Builder. A fresh check-in with no
    // further progress resumes here; `UpdateWorkflowStep` overwrites this once
    // the rep advances into a business task (see the guard below).
    VisitWorkflow? workflow = VisitWorkflow.stockCount;
    String? screen = InventoryVisibilityScreen.routeName;
    Map<String, dynamic>? args = {
      'stopId': stop.id,
      'depotId': stop.depot.id,
      'depotName': stop.depot.name,
      'territory': stop.depot.territory,
    };

    // Never *downgrade* a business task the rep already advanced into
    // (Quotation/Sales Order) back to Stock Count when a later route event
    // re-persists for the same stop — that would strand "Continue Working" on
    // the wrong screen. Deferred check-out means the stop stays checked in
    // through those tasks, so this guard keeps the resume pointer stable.
    final existingResult = await _get(const NoParams());
    final existing =
        existingResult.when(success: (w) => w, failure: (_) => null);
    final sameStop = existing != null && existing.currentStopId == stop.id;

    if (sameStop && (existing.currentWorkflow?.isBusinessTask ?? false)) {
      workflow = existing.currentWorkflow;
      screen = existing.currentScreen;
      args = existing.navigationArguments ?? args;
    } else if (sameStop) {
      // Same stop, still on a guided step: refresh the baseline keys but
      // keep anything a step recorded for itself.
      //
      // This is what was destroying in-progress work. A guided step is not a
      // "business task", so the branch above never protected it, and any
      // later route event re-ran this write and replaced the whole argument
      // map — taking the half-finished stock audit with it. The rep tapped
      // four items, the app saved them, and the next route rebuild wiped
      // them. Merging keeps the step's own state alive while the baseline
      // stays authoritative for the keys it owns.
      args = {...?existing.navigationArguments, ...args};
      // Keep a more advanced guided screen (e.g. the post-audit decision)
      // rather than resetting to the audit the rep already finished.
      screen = existing.currentScreen ?? screen;
    }

    await _save(ActiveWorkflow(
      routeId: state.route.id,
      currentStopId: stop.id,
      dayStarted: state.dayStarted,
      updatedAt: now,
      depotId: stop.depot.id,
      shopName: stop.depot.name,
      checkInAt: stop.actualArrival,
      currentWorkflow: workflow,
      currentScreen: screen,
      navigationArguments: args,
      workflowUpdatedAt: now,
    ));
  }
}
