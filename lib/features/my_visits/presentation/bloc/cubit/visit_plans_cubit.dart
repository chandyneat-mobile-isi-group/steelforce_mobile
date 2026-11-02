import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_today_visit_plans.dart';
import 'package:steelforce/features/my_visits/domain/usecases/skip_visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_plans_state.dart';

/// Loads today's visits for the Visits list (`GET /api/v1/mobile/plans/today`).
///
/// One request at a time: a second [load] or [refresh] while one is in flight
/// joins it instead of sending another.
class VisitPlansCubit extends Cubit<VisitPlansState> {
  VisitPlansCubit({
    required GetTodayVisitPlans getTodayVisitPlans,
    required SkipVisitPlan skipVisitPlan,
    Stream<Object?>? synced,
  })  : _getTodayVisitPlans = getTodayVisitPlans,
        _skipVisitPlan = skipVisitPlan,
        super(const VisitPlansLoading()) {
    // Steps sent from the outbox change what the list shows: reload then.
    _syncedSub = synced?.listen((_) {
      if (state is! VisitPlansLoading) refresh();
    });
  }

  final GetTodayVisitPlans _getTodayVisitPlans;
  final SkipVisitPlan _skipVisitPlan;
  StreamSubscription<Object?>? _syncedSub;

  @override
  Future<void> close() async {
    await _syncedSub?.cancel();
    return super.close();
  }

  Future<void>? _inFlight;

  /// Loads today's plan. Safe to call repeatedly.
  Future<void> load() => _fetch();

  /// Re-fetches, keeping a loaded list on screen.
  Future<void> refresh() => _fetch();

  /// Skips [plan] with [reason], then reloads the list so the card shows the
  /// server's new status. Returns the failure for the sheet to show, or null.
  Future<Failure?> skip(VisitPlan plan, String reason) async {
    final result = await _skipVisitPlan(
        SkipVisitPlanParams(planId: plan.id, reason: reason));
    if (isClosed) return null;
    switch (result) {
      case Success():
        // A load already in flight started before the skip; wait it out so
        // the reload is a fresh one that includes it.
        await _inFlight;
        if (!isClosed) await refresh();
        return null;
      case Failed(:final failure):
        return failure;
    }
  }

  Future<void> _fetch() {
    final pending = _inFlight;
    if (pending != null) return pending;

    final current = state;
    if (current is VisitPlansLoaded) {
      emit(VisitPlansLoaded(current.overview, refreshing: true));
    } else if (current is! VisitPlansLoading) {
      emit(const VisitPlansLoading());
    }
    return _inFlight = _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    final result = await _getTodayVisitPlans(const NoParams());
    if (isClosed) return;

    switch (result) {
      case Success(:final data):
        emit(data.isEmpty ? VisitPlansEmpty(data) : VisitPlansLoaded(data));
      case Failed(:final failure):
        final current = state;
        emit(current is VisitPlansLoaded
            ? VisitPlansLoaded(current.overview, refreshFailure: failure)
            : VisitPlansFailure(failure));
    }
  }
}
