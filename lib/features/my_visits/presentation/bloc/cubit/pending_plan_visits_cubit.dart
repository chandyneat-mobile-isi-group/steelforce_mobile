import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';
import 'package:steelforce/features/my_visits/domain/usecases/plan_visit_steps_held.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_pending_plan_visits.dart';

class PendingPlanVisitsState extends Equatable {
  const PendingPlanVisitsState({
    this.visits = const [],
    this.busy = const {},
    this.messageKey,
    this.messageSeq = 0,
  });

  final List<PendingPlanVisit> visits;

  /// Visits whose resend or discard is in progress.
  final Set<String> busy;

  /// A localisation key for the outcome of a rep action.
  final String? messageKey;

  /// Bumped with every message, so the same message twice is a new state.
  final int messageSeq;

  PendingPlanVisitsState copyWith({
    List<PendingPlanVisit>? visits,
    Set<String>? busy,
    String? messageKey,
  }) =>
      PendingPlanVisitsState(
        visits: visits ?? this.visits,
        busy: busy ?? this.busy,
        messageKey: messageKey,
        messageSeq: messageKey == null ? messageSeq : messageSeq + 1,
      );

  @override
  List<Object?> get props => [visits, busy, messageKey, messageSeq];
}

/// Planned visits whose check-in, inventory photos or check-out wait on this
/// device, for the Sync Center. The sync engine sends them on its own, and
/// with the Center's **Sync Now**; a step the server refused waits for the
/// rep to **Send again** or **Discard**.
class PendingPlanVisitsCubit extends Cubit<PendingPlanVisitsState> {
  PendingPlanVisitsCubit({
    required WatchPendingPlanVisits watch,
    required ResendPlanVisitSteps resend,
    required DiscardPlanVisitSteps discard,
  })  : _resend = resend,
        _discard = discard,
        super(const PendingPlanVisitsState()) {
    _sub = watch(const NoParams()).listen(
      (visits) {
        if (!isClosed) emit(state.copyWith(visits: visits));
      },
      // A read that fails leaves the last list up; the next change retries.
      onError: (Object _) {},
    );
  }

  final ResendPlanVisitSteps _resend;
  final DiscardPlanVisitSteps _discard;
  late final StreamSubscription<List<PendingPlanVisit>> _sub;

  Future<void> resend(String planId) => _run(
        planId,
        () => _resend(planId),
        done: 'sync_center.plan.resent',
      );

  Future<void> discard(String planId) => _run(
        planId,
        () => _discard(planId),
        done: 'sync_center.plan.discarded',
      );

  Future<void> _run(
    String planId,
    ResultFuture<void> Function() action, {
    required String done,
  }) async {
    if (state.busy.contains(planId)) return;
    emit(state.copyWith(busy: {...state.busy, planId}));
    final result = await action();
    if (isClosed) return;
    emit(state.copyWith(
      busy: {...state.busy}..remove(planId),
      messageKey: result is Failed ? 'sync_center.plan.action_failed' : done,
    ));
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
