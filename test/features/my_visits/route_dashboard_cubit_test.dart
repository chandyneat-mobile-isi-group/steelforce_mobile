import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_all_routes.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_dashboard_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/route_dashboard_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchAllRoutes extends Mock implements WatchAllRoutes {}

DepotStopInfo _depot(String id, {double lat = 11.55, double lng = 104.92}) =>
    DepotStopInfo(
      id: id,
      name: 'Shop $id',
      code: 'C$id',
      contact: 'Owner',
      phone: '012000000',
      address: 'Phnom Penh',
      territory: 'PP',
      territoryType: TerritoryType.urban,
      latitude: lat,
      longitude: lng,
    );

RouteStop _stop(
  String id, {
  required VisitStatus status,
  double lat = 11.55,
  double lng = 104.92,
}) {
  final base = DateTime.now().toUtc();
  return RouteStop(
    id: id,
    routeId: 'R1',
    depot: _depot(id, lat: lat, lng: lng),
    sequence: int.parse(id),
    plannedArrival: base,
    plannedDeparture: base.add(const Duration(minutes: 30)),
    status: status,
  );
}

RoutePlan _routeToday(List<RouteStop> stops) {
  final today = DateTime.now().toUtc();
  return RoutePlan(
    id: 'R1',
    name: 'Test Route',
    repId: 'E1',
    repName: 'Sokha',
    territory: 'PP',
    // The cubit narrows to "today" by UTC calendar day, so the fixture must be
    // UTC-anchored the same way the production mappers are.
    visitDate: DateTime.utc(today.year, today.month, today.day),
    plannedStart: today,
    plannedEnd: today.add(const Duration(hours: 8)),
    status: RouteStatus.inProgress,
    stops: stops,
  );
}

Future<RouteDashboardSummaryView> _summaryFor(List<RouteStop> stops) async {
  final watch = _MockWatchAllRoutes();
  when(() => watch(const NoParams()))
      .thenAnswer((_) => Stream.value([_routeToday(stops)]));

  final cubit = RouteDashboardCubit(watchAllRoutes: watch);
  addTearDown(cubit.close);

  final state = await cubit.stream.firstWhere((s) => s is RouteDashboardLoaded)
      as RouteDashboardLoaded;
  return RouteDashboardSummaryView(state);
}

/// Tiny read-only wrapper so the assertions below read as prose.
class RouteDashboardSummaryView {
  RouteDashboardSummaryView(this.state);
  final RouteDashboardLoaded state;

  double get progress => state.summary.progress;
  double get successRate => state.summary.successRate;
  int get drivingMinutes => state.summary.drivingTimeMinutes;
  int get completed => state.summary.completed;
  int get missed => state.summary.missed;
  int get remaining => state.summary.remaining;
}

void main() {
  setUpAll(() => registerFallbackValue(const NoParams()));

  group('RouteDashboardCubit summary', () {
    test('successRate measures attempted stops, not planned ones', () async {
      // 1 completed, 1 missed, 2 still pending.
      final view = await _summaryFor([
        _stop('1', status: VisitStatus.checkedOut),
        _stop('2', status: VisitStatus.missed),
        _stop('3', status: VisitStatus.pending),
        _stop('4', status: VisitStatus.pending),
      ]);

      // Of the 2 attempted, 1 succeeded.
      expect(view.successRate, 0.5);
      // Of the 4 planned, 1 is done — deliberately different from successRate.
      expect(view.progress, 0.25);
      expect(view.successRate, isNot(view.progress));
    });

    test('successRate is 0 when nothing has been attempted yet', () async {
      final view = await _summaryFor([
        _stop('1', status: VisitStatus.pending),
        _stop('2', status: VisitStatus.pending),
      ]);

      expect(view.successRate, 0);
      expect(view.progress, 0);
    });

    test('counts split correctly across completed / missed / remaining',
        () async {
      final view = await _summaryFor([
        _stop('1', status: VisitStatus.checkedOut),
        _stop('2', status: VisitStatus.checkedOut),
        _stop('3', status: VisitStatus.missed),
        _stop('4', status: VisitStatus.pending),
      ]);

      expect(view.completed, 2);
      expect(view.missed, 1);
      expect(view.remaining, 1);
    });

    test('driving time is estimated from inter-stop distance, not left at 0',
        () async {
      // Two stops ~11 km apart (0.1 degree of latitude).
      final view = await _summaryFor([
        _stop('1', status: VisitStatus.checkedOut, lat: 11.50),
        _stop('2', status: VisitStatus.checkedOut, lat: 11.60),
      ]);

      expect(view.drivingMinutes, greaterThan(0));
    });

    test('a single stop implies no travel', () async {
      final view = await _summaryFor([
        _stop('1', status: VisitStatus.checkedOut),
      ]);

      expect(view.drivingMinutes, 0);
    });
  });
}
