import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';

class NavigationStateData extends Equatable {
  const NavigationStateData({this.workflow, this.loaded = false});

  /// The persisted navigation pointer, or null when there's no active visit.
  final ActiveWorkflow? workflow;
  final bool loaded;

  /// True once the rep has checked into a Shop/Depot on the active visit —
  /// the gate for showing the workflow-aware "Continue Working" card.
  bool get hasActiveVisit => workflow?.hasCheckedIn ?? false;

  /// The Shop/Depot id the active visit belongs to — the dedup key against
  /// Order-feature drafts.
  String? get shopId => workflow?.depotId;
  String? get shopName => workflow?.shopName;

  /// The Route Stop id the rep is checked into — the pointer used to deep-link
  /// a workflow resume straight back to the correct stop instead of dropping
  /// the rep on stop selection.
  String? get stopId => workflow?.currentStopId;

  /// The business activity the rep last entered on the active visit.
  VisitWorkflow? get currentWorkflow => workflow?.currentWorkflow;

  @override
  List<Object?> get props => [workflow, loaded];
}

/// Owns the rep's **navigation state** (which Shop/Depot + business activity
/// the active visit is in), deliberately kept separate from the business
/// `VisitCubit` (capture data) per the feature brief.
///
/// A read-side twin of [ResumableVisitCubit]: that one resolves the route
/// *object* to resume into; this one exposes the workflow label + shop id that
/// let the Home card say "Continue Quotation" and dedupe against Order drafts.
/// Registered as a lazy singleton so its state survives tab switches; the shell
/// [refresh]es it whenever Home is shown or a visit screen closes.
class NavigationStateCubit extends Cubit<NavigationStateData> {
  NavigationStateCubit({
    required GetActiveWorkflow getActiveWorkflow,
    required CompleteVisitCheckOut completeVisitCheckOut,
  })  : _getActiveWorkflow = getActiveWorkflow,
        _completeVisitCheckOut = completeVisitCheckOut,
        super(const NavigationStateData()) {
    refresh();
  }

  final GetActiveWorkflow _getActiveWorkflow;
  final CompleteVisitCheckOut _completeVisitCheckOut;

  bool _loading = false;

  /// Re-reads the persisted navigation pointer. Guarded against overlapping
  /// runs. Advisory only — never clears/heals the pointer itself (that's
  /// [GetResumableRoute]'s job, driven by [ResumableVisitCubit]).
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await _getActiveWorkflow(const NoParams());
      final workflow = result.when(success: (w) => w, failure: (_) => null);
      if (!isClosed) {
        emit(NavigationStateData(workflow: workflow, loaded: true));
      }
    } finally {
      _loading = false;
    }
  }

  /// Completes the deferred check-out for the active visit (writes the checkout
  /// record + marks the stop checked-out) and clears the navigation state.
  Future<void> checkOut(CheckOutChoice? choice) async {
    await _completeVisitCheckOut(choice);
    await refresh();
  }
}
