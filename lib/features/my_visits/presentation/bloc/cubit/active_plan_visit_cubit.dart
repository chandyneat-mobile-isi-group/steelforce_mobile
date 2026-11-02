import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_today_visit_plans.dart';
import 'package:steelforce/features/my_visits/domain/usecases/is_plan_inventory_done.dart';

class ActivePlanVisitState extends Equatable {
  const ActivePlanVisitState({
    this.plan,
    this.loaded = false,
    this.inventoryDone = false,
  });

  /// Today's checked-in visit the rep can carry on with, or null.
  final VisitPlan? plan;
  final bool loaded;

  /// [plan] has its inventory photos, so Check out can be offered. Until
  /// then the only way on is Continue, into the photo step.
  final bool inventoryDone;

  @override
  List<Object?> get props => [plan, loaded, inventoryDone];
}

/// The visit a rep checked in to and has not checked out of — Home's
/// "Continue visit" card for the plans API.
///
/// The server's status is the source of truth: a plan check-in writes no
/// local resume pointer, so this reads `GET /mobile/plans/today` (or its
/// offline copy) and keeps the one that is CheckedIn. A failed read keeps
/// what was shown, so a dropped connection does not hide an open visit.
class ActivePlanVisitCubit extends Cubit<ActivePlanVisitState> {
  ActivePlanVisitCubit({
    required GetTodayVisitPlans getTodayVisitPlans,
    required IsPlanInventoryDone isInventoryDone,
  })  : _getTodayVisitPlans = getTodayVisitPlans,
        _isInventoryDone = isInventoryDone,
        super(const ActivePlanVisitState());

  final GetTodayVisitPlans _getTodayVisitPlans;
  final IsPlanInventoryDone _isInventoryDone;
  final Set<String> _dismissed = {};
  bool _loading = false;

  /// Re-reads today's plans. A second call while one runs is dropped.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await _getTodayVisitPlans(const NoParams());
      if (isClosed) return;
      switch (result) {
        case Success(data: final overview):
          final plan = overview.items
              .where((p) =>
                  p.status == VisitPlanStatus.checkedIn &&
                  !_dismissed.contains(p.id))
              .firstOrNull;
          final done = plan != null &&
              switch (await _isInventoryDone(plan.id)) {
                Success(:final data) => data,
                Failed() => false,
              };
          if (isClosed) return;
          emit(ActivePlanVisitState(
              loaded: true, plan: plan, inventoryDone: done));
        case Failed():
          if (!state.loaded) emit(const ActivePlanVisitState(loaded: true));
      }
    } finally {
      _loading = false;
    }
  }

  /// Hides the card for this visit until the app is opened again. The visit
  /// stays checked in on the server — it is still in the Visits list.
  void dismiss() {
    final plan = state.plan;
    if (plan == null) return;
    _dismissed.add(plan.id);
    emit(const ActivePlanVisitState(loaded: true));
  }
}
