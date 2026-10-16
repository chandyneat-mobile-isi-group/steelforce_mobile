import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_today_routes.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_today_routes.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/today_call_plan_count_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockRouteRepository extends Mock implements RouteRepository {}

RouteStop _stop(String id, {VisitSource source = VisitSource.callPlan}) =>
    RouteStop(
      id: id,
      routeId: 'r',
      depot: const DepotStopInfo(
        id: 'd',
        name: 'Depot',
        code: 'C',
        contact: '',
        phone: '',
        address: '',
        territory: 'PP',
        territoryType: TerritoryType.urban,
        latitude: 0,
        longitude: 0,
      ),
      sequence: source == VisitSource.adHoc ? 1001 : 1,
      plannedArrival: null,
      plannedDeparture: null,
      status: VisitStatus.pending,
      visitSource: source,
    );

RoutePlan _route(String id, List<RouteStop> stops) => RoutePlan(
      id: id,
      name: id,
      repId: 'rep',
      repName: 'Rep',
      territory: 'PP',
      visitDate: DateTime(2026, 9, 30),
      plannedStart: DateTime(2026, 9, 30, 8),
      plannedEnd: DateTime(2026, 9, 30, 17),
      status: RouteStatus.published,
      stops: stops,
    );

void main() {
  late _MockRouteRepository repo;
  late StreamController<List<RoutePlan>> live;

  setUp(() {
    repo = _MockRouteRepository();
    live = StreamController<List<RoutePlan>>();
    when(() => repo.watchTodayRoutes()).thenAnswer((_) => live.stream);
  });

  // Not awaited: a single-subscription controller nobody listened to never
  // completes its close future, and the pure-function test never listens.
  tearDown(() => unawaited(live.close()));

  TodayCallPlanCountCubit build() => TodayCallPlanCountCubit(
        watchTodayRoutes: WatchTodayRoutes(repo),
        fetchTodayRoutes: FetchTodayRoutes(repo),
      );

  test('counts Call Plan stops across every route today, not ad hoc ones', () {
    final routes = [
      _route('a', [_stop('1'), _stop('2')]),
      _route('b', [_stop('3'), _stop('4', source: VisitSource.adHoc)]),
    ];

    expect(countCallPlanStops(routes), 3);
    expect(countCallPlanStops(const []), 0);
  });

  test('is null until the first read, so the badge never flashes a wrong 0',
      () async {
    final cubit = build();
    expect(cubit.state, isNull);
    await cubit.close();
  });

  test('refresh reads the synced routes', () async {
    when(() => repo.fetchTodayRoutes()).thenAnswer((_) async => Success([
          _route('a', [_stop('1'), _stop('2')]),
        ]));
    final cubit = build();

    await cubit.refresh();

    expect(cubit.state, 2);
    await cubit.close();
  });

  test('live local changes update the count', () async {
    final cubit = build();

    live.add([
      _route('a', [_stop('1')]),
    ]);
    await pumpEventQueue();

    expect(cubit.state, 1);
    await cubit.close();
  });

  test('a failed refresh keeps the last good count', () async {
    when(() => repo.fetchTodayRoutes()).thenAnswer((_) async => Success([
          _route('a', [_stop('1'), _stop('2')]),
        ]));
    final cubit = build();
    await cubit.refresh();

    when(() => repo.fetchTodayRoutes())
        .thenAnswer((_) async => const Failed(CacheFailure(message: 'x')));
    await cubit.refresh();

    expect(cubit.state, 2);
    await cubit.close();
  });
}
