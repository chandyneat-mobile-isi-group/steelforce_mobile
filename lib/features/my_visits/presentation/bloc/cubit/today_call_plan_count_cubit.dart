import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_today_visit_plans.dart';

/// How many visits the rep has today — the Home "My Visits" badge.
///
/// Read from `GET /api/v1/mobile/plans/today`, the source of the Visits tab
/// itself, and counted the way the tab's calendar dot counts: one per visit
/// in the list. It used to count the old route mirror (`/mobile/routes`),
/// which the Visits tab no longer reads — so the badge said "0 today" over a
/// list of five.
///
/// State is `null` until the first answer lands, so the badge stays hidden
/// rather than flashing a wrong "0 today". A failed read (offline, server
/// down) keeps the last count: the plans are not mirrored on the device yet.
class TodayCallPlanCountCubit extends Cubit<int?> {
  TodayCallPlanCountCubit({required GetTodayVisitPlans getTodayVisitPlans})
      : _getTodayVisitPlans = getTodayVisitPlans,
        super(null);

  final GetTodayVisitPlans _getTodayVisitPlans;

  Future<void> refresh() async {
    final result = await _getTodayVisitPlans(const NoParams());
    if (isClosed) return;
    result.when(
      success: (overview) => emit(overview.items.length),
      failure: (_) {},
    );
  }
}
