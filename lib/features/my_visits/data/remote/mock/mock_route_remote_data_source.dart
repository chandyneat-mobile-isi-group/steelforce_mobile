// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
//
// [RouteRemoteDataSource] for the static web demo: the route pull built from
// [MockVisitWorld]'s plans — one route a day, one stop per visit, the stop id
// being the plan id — with no network call. Parsed through the same
// `fromJson` factories as the live source, so the demo runs the real models.
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_stop_model.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_world.dart';
import 'package:steelforce/features/my_visits/data/remote/route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/route_sync_page.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

class MockRouteRemoteDataSource implements RouteRemoteDataSource {
  const MockRouteRemoteDataSource(this._world);

  final MockVisitWorld _world;

  /// Route-name key the dashboard renders through `.tr`.
  static const String _routeNameKey = 'my_visits.route_info.plan_daily';

  @override
  Future<RouteSyncPage> fetchInitial({
    required RouteSyncScope scope,
    required int page,
    required int pageSize,
  }) async {
    await MockLatency.tick();
    final all = _routes();
    final start = (page * pageSize).clamp(0, all.length);
    final end = (start + pageSize).clamp(0, all.length);
    return _page(all.sublist(start, end), hasMore: end < all.length);
  }

  /// The rep's whole current set, which a delta may return every time.
  @override
  Future<RouteSyncPage> fetchDelta({
    required RouteSyncScope scope,
    required DateTime since,
  }) async {
    await MockLatency.tick();
    return _page(_routes(), hasMore: false);
  }

  /// The visits grouped into one route a day, oldest first.
  List<List<MockVisitRecord>> _routes() {
    final byDay = <DateTime, List<MockVisitRecord>>{};
    for (final visit in _world.visits) {
      byDay.putIfAbsent(visit.day, () => []).add(visit);
    }
    final days = byDay.keys.toList()..sort();
    return [for (final day in days) byDay[day]!];
  }

  RouteSyncPage _page(List<List<MockVisitRecord>> routes,
      {required bool hasMore}) {
    final depots = <String, DepotStopInfoModel>{
      for (final route in routes)
        for (final visit in route) visit.depot.code: _depot(visit.depot),
    };
    return RouteSyncPage(
      depots: depots.values.toList(),
      routes: [
        for (final route in routes)
          RoutePlanModel.fromJson(_routeJson(route), stops: [
            for (var i = 0; i < route.length; i++)
              RouteStopModel.fromJson(_stopJson(route[i], i),
                  depot: depots[route[i].depot.code]!),
          ]),
      ],
      generatedAt: _world.now().toUtc(),
      territories: const [MockVisitWorld.territory],
      hasMore: hasMore,
    );
  }

  static DepotStopInfoModel _depot(MockVisitDepot depot) =>
      DepotStopInfoModel.fromJson({
        'id': depot.code,
        'name': depot.name,
        'code': depot.code,
        'contact': '',
        'phone': '',
        'address': 'Phnom Penh',
        'territory': MockVisitWorld.territory,
        'territoryType': 'urban',
        'latitude': depot.latitude,
        'longitude': depot.longitude,
      });

  DataMap _routeJson(List<MockVisitRecord> route) {
    final day = route.first.day;
    return {
      'id': _routeId(day),
      'name': _routeNameKey,
      'repId': MockVisitWorld.repId,
      'repName': MockVisitWorld.repName,
      'territory': MockVisitWorld.territory,
      'visitDate': DateTime.utc(day.year, day.month, day.day).toIso8601String(),
      'plannedStart': _at(day, 8, 0).toIso8601String(),
      'plannedEnd': _at(day, 17, 0).toIso8601String(),
      'status': _routeStatus(route),
    };
  }

  DataMap _stopJson(MockVisitRecord visit, int index) {
    final arrival = _at(visit.day, 8, index * 75);
    return {
      'id': visit.id,
      'routeId': _routeId(visit.day),
      'sequence': visit.adHoc ? 1001 + index : index + 1,
      'plannedArrival': visit.adHoc ? null : arrival.toIso8601String(),
      'plannedDeparture': visit.adHoc
          ? null
          : arrival.add(const Duration(minutes: 45)).toIso8601String(),
      'status': switch (visit.status) {
        VisitPlanStatus.checkedIn => 'checkedIn',
        VisitPlanStatus.completed => 'checkedOut',
        VisitPlanStatus.missed || VisitPlanStatus.skipped => 'missed',
        _ => 'pending',
      },
      'visitSource': visit.adHoc ? 'adHoc' : 'callPlan',
      'actualArrival': visit.checkedInAt?.toIso8601String(),
      'actualDeparture': visit.checkedOutAt?.toIso8601String(),
    };
  }

  /// A day nobody has started is published; one under way is in progress;
  /// one with nothing left open is completed.
  static String _routeStatus(List<MockVisitRecord> route) {
    if (route.every((v) => !v.isOpen)) return 'completed';
    if (route.any((v) =>
        v.status == VisitPlanStatus.checkedIn ||
        v.status == VisitPlanStatus.completed)) {
      return 'inProgress';
    }
    return 'published';
  }

  static String _routeId(DateTime day) =>
      'demo-route-${day.toIso8601String().split('T').first}';

  /// [hour]:[minutes] local on [day], as UTC.
  static DateTime _at(DateTime day, int hour, int minutes) =>
      DateTime(day.year, day.month, day.day, hour, minutes).toUtc();
}
