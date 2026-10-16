import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/clear_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_resumable_route.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';

class ResumableVisitState extends Equatable {
  const ResumableVisitState({this.route, this.workflow, this.loaded = false});

  /// The in-progress route the rep can resume, or null when there's nothing to
  /// continue (never started, already finished, or dismissed).
  final RoutePlan? route;

  /// The persisted navigation pointer for that route — the workflow/screen/args
  /// the resume dispatcher uses to restore the *exact* screen. Null on the pure
  /// route-only resume path.
  final ActiveWorkflow? workflow;
  final bool loaded;

  bool get hasResumable => route != null;

  /// The Shop/Depot id the rep is currently checked into on the active visit,
  /// or null when there's no checked-in visit. Used to dedup the Home cards:
  /// an Order draft for this shop is folded into the visit card.
  String? get activeShopId =>
      (workflow?.hasCheckedIn ?? false) ? workflow?.depotId : null;

  @override
  List<Object?> get props => [route, workflow, loaded];
}

/// The visit-flow twin of [ContinueWorkCubit]: surfaces the rep's in-progress
/// check-in (the "active workflow") so it can be resumed from the Home
/// Continue-Working section instead of the old app-launch auto-redirect.
///
/// Registered as a lazy singleton so its state survives tab switches; the shell
/// calls [refresh] whenever the Home tab is shown or a route screen is closed,
/// which is what makes "clear the old, show the new" work — [GetResumableRoute]
/// self-heals a stale/finished pointer to null, and a fresh check-in overwrites
/// it with the current route.
class ResumableVisitCubit extends Cubit<ResumableVisitState> {
  ResumableVisitCubit({
    required GetResumableRoute getResumableRoute,
    required GetRoute getRoute,
    required GetActiveWorkflow getActiveWorkflow,
    required ClearActiveWorkflow clearActiveWorkflow,
    required CompleteVisitCheckOut completeVisitCheckOut,
  })  : _getResumableRoute = getResumableRoute,
        _getRoute = getRoute,
        _getActiveWorkflow = getActiveWorkflow,
        _clearActiveWorkflow = clearActiveWorkflow,
        _completeVisitCheckOut = completeVisitCheckOut,
        super(const ResumableVisitState()) {
    refresh();
  }

  final GetResumableRoute _getResumableRoute;
  final GetRoute _getRoute;
  final GetActiveWorkflow _getActiveWorkflow;
  final ClearActiveWorkflow _clearActiveWorkflow;
  final CompleteVisitCheckOut _completeVisitCheckOut;

  bool _loading = false;

  /// Re-resolves the resumable route *and* its persisted workflow pointer, so
  /// the card can restore the exact screen. Guarded against overlapping runs.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final idResult = await _getResumableRoute(const NoParams());
      final routeId = idResult.when(success: (id) => id, failure: (_) => null);
      if (routeId == null) {
        if (!isClosed) emit(const ResumableVisitState(loaded: true));
        return;
      }
      final routeResult = await _getRoute(RouteIdParams(routeId));
      final route = routeResult.when(success: (r) => r, failure: (_) => null);
      final workflowResult = await _getActiveWorkflow(const NoParams());
      final workflow =
          workflowResult.when(success: (w) => w, failure: (_) => null);
      if (!isClosed) {
        emit(ResumableVisitState(
            route: route, workflow: workflow, loaded: true));
      }
    } finally {
      _loading = false;
    }
  }

  /// User chose not to continue — clears the active workflow so the card goes
  /// away and won't reappear until the next check-in.
  Future<void> dismiss() async {
    await _clearActiveWorkflow(const NoParams());
    if (!isClosed) emit(const ResumableVisitState(loaded: true));
  }

  /// Completes the deferred check-out for the active visit (writes the checkout
  /// record + marks the stop checked-out) and clears the resume pointer — the
  /// explicit end of a visit now that Stock Count no longer auto-checks-out.
  Future<void> checkOut(CheckOutChoice? choice) async {
    await _completeVisitCheckOut(choice);
    await refresh();
  }
}
