import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_my_visit_plans.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_plan_calendar_state.dart';

/// Feeds the Visits calendar from `GET /api/v1/mobile/plans?period=ThisMonth`.
///
/// The endpoint only answers Today, ThisWeek or ThisMonth, so the calendar
/// knows the current month and nothing beyond it.
class VisitPlanCalendarCubit extends Cubit<VisitPlanCalendarState> {
  VisitPlanCalendarCubit({
    required GetMyVisitPlans getMyVisitPlans,
    DateTime Function() clock = DateTime.now,
    Stream<Object?>? synced,
  })  : _getMyVisitPlans = getMyVisitPlans,
        _clock = clock,
        super(VisitPlanCalendarState(selectedDate: _day(clock()))) {
    // Steps sent from the outbox change the statuses: reload then.
    _syncedSub = synced?.listen((_) => load());
  }

  final GetMyVisitPlans _getMyVisitPlans;
  final DateTime Function() _clock;
  StreamSubscription<Object?>? _syncedSub;

  @override
  Future<void> close() async {
    await _syncedSub?.cancel();
    return super.close();
  }

  Future<void>? _inFlight;

  DateTime get today => _day(_clock());

  bool get isTodaySelected => state.selectedDate == today;

  /// Loads this month's plans. Joins a load already in flight.
  Future<void> load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    emit(state.copyWith(
        status: VisitPlanCalendarStatus.loading, clearFailure: true));
    return _inFlight = _run().whenComplete(() => _inFlight = null);
  }

  void selectDate(DateTime date) =>
      emit(state.copyWith(selectedDate: _day(date)));

  Future<void> _run() async {
    final result = await _getMyVisitPlans(PlanPeriod.thisMonth);
    if (isClosed) return;
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
            status: VisitPlanCalendarStatus.loaded,
            month: data,
            clearFailure: true));
      case Failed(:final failure):
        emit(state.copyWith(
            status: VisitPlanCalendarStatus.failed, failure: failure));
    }
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
