import 'dart:async';

import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_visit_data.dart';

/// [RouteRepository] for a practice lesson: today holds exactly the demo route
/// ([PracticeVisitData]), and every status change to it stays in memory.
///
/// * Lists (`fetch…` / `watch…`) show the practice world only, so the first
///   card on the dashboard is the demo stop.
/// * A call naming a real route or stop goes to the real repository — a
///   practice run never swallows real work.
/// * Once [PracticeWorld.isClosed], **every** call goes to the real one (see
///   `PracticeSession` on captured stand-ins).
class PracticeRouteRepository implements RouteRepository {
  PracticeRouteRepository(this._real, this._world, {DateTime Function()? now})
      : _route = PracticeVisitData.route((now ?? DateTime.now)()) {
    _world.onClose(() async => _changes.close());
  }

  final RouteRepository _real;
  final PracticeWorld _world;

  RoutePlan _route;

  /// The demo route as it stands now — for tests and diagnostics.
  RoutePlan get route => _route;

  final StreamController<List<RoutePlan>> _changes =
      StreamController<List<RoutePlan>>.broadcast();

  bool get _live => !_world.isClosed;

  List<RoutePlan> get _routes => [_route];

  @override
  ResultFuture<List<RoutePlan>> fetchTodayRoutes() async {
    if (!_live) return _real.fetchTodayRoutes();
    return Success(_routes);
  }

  @override
  ResultFuture<List<RoutePlan>> fetchAllRoutes() async {
    if (!_live) return _real.fetchAllRoutes();
    return Success(_routes);
  }

  @override
  Stream<List<RoutePlan>> watchTodayRoutes() =>
      _live ? _watch() : _real.watchTodayRoutes();

  @override
  Stream<List<RoutePlan>> watchAllRoutes() =>
      _live ? _watch() : _real.watchAllRoutes();

  /// The current snapshot on listen, then every change.
  Stream<List<RoutePlan>> _watch() => Stream.multi((controller) {
        controller.add(_routes);
        final sub = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  void _emit() {
    if (!_changes.isClosed) _changes.add(_routes);
  }

  @override
  ResultFuture<RoutePlan> getRoute(String routeId) async {
    if (_live && routeId == _route.id) return Success(_route);
    return _real.getRoute(routeId);
  }

  @override
  Future<void> notifyStopsChanged() async {
    if (!_live) return _real.notifyStopsChanged();
    _emit();
  }

  @override
  ResultFuture<void> updateRouteStatus(
      String routeId, RouteStatus status) async {
    if (!_live || routeId != _route.id) {
      return _real.updateRouteStatus(routeId, status);
    }
    _route = _route.copyWith(status: status);
    _emit();
    return const Success(null);
  }

  @override
  ResultFuture<void> updateStopStatus(
    String stopId, {
    required VisitStatus status,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  }) async {
    if (!_live || !PracticeIds.isPractice(stopId)) {
      return _real.updateStopStatus(
        stopId,
        status: status,
        actualArrival: actualArrival,
        actualDeparture: actualDeparture,
      );
    }
    _route = _route.copyWith(stops: [
      for (final s in _route.stops)
        if (s.id == stopId)
          s.copyWith(
            status: status,
            actualArrival: actualArrival,
            actualDeparture: actualDeparture,
          )
        else
          s,
    ]);
    _emit();
    return const Success(null);
  }
}
