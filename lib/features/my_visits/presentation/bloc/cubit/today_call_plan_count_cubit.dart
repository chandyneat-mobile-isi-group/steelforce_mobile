import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_today_routes.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_today_routes.dart';

/// How many **Call Plan** stops the rep has today — the Home "My Visits"
/// badge.
///
/// Read from the local route mirror, which is what the route sync fills from
/// `GET /mobile/routes`: the badge must answer offline, and it is the same
/// number the My Visits tab shows. Ad hoc visits are excluded — the rep added
/// those, the plan did not.
///
/// State is `null` until the first read lands, so the badge stays hidden
/// rather than flashing a wrong "0 today".
///
/// Two inputs, because neither is enough alone:
///  * [WatchTodayRoutes] pushes local changes (check-in, check-out) live;
///  * route sync writes through a different repository that never reaches that
///    stream, so [refresh] re-reads — the Home tab calls it when shown.
class TodayCallPlanCountCubit extends Cubit<int?> {
  TodayCallPlanCountCubit({
    required WatchTodayRoutes watchTodayRoutes,
    required FetchTodayRoutes fetchTodayRoutes,
  })  : _fetchTodayRoutes = fetchTodayRoutes,
        super(null) {
    _subscription = watchTodayRoutes(const NoParams()).listen(
      _emitFrom,
      // A failed local read keeps the last good count rather than blanking it.
      onError: (Object _) {},
    );
  }

  final FetchTodayRoutes _fetchTodayRoutes;
  StreamSubscription<List<RoutePlan>>? _subscription;

  Future<void> refresh() async {
    final result = await _fetchTodayRoutes(const NoParams());
    result.when(success: _emitFrom, failure: (_) {});
  }

  void _emitFrom(List<RoutePlan> routes) {
    if (isClosed) return;
    emit(countCallPlanStops(routes));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

/// Call Plan stops across [routes]; ad hoc visits do not count.
int countCallPlanStops(List<RoutePlan> routes) => routes.fold(
      0,
      (sum, route) => sum + route.stops.where((s) => !s.isAdHoc).length,
    );
