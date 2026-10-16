import 'package:steelforce/core/database/drift/daos/route_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_mappers.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// [RouteLocalDataSource] backed by the single encrypted Drift database
/// (T1.5 cutover). Replaces the plaintext `routes.db` implementation.
///
/// The interface is unchanged, so the repository, usecases and blocs above are
/// untouched by the storage swap (ADR-003 seam, `docs/blueprint/system-architecture.md` §5).
class RouteDriftLocalDataSource implements RouteLocalDataSource {
  const RouteDriftLocalDataSource(this._dao, this._logger);

  final RouteDao _dao;
  final AppLogger _logger;

  @override
  Future<List<RoutePlanModel>> fetchTodayRoutes() async {
    try {
      final routes = await _dao.fetchRoutesForDay(DateTime.now().toUtc());
      // Sequential rather than concurrent: a rep has a handful of routes per
      // day, and serialising keeps the read off a connection-contention path.
      final plans = <RoutePlanModel>[];
      for (final route in routes) {
        plans.add(route.toModel(await _stopsFor(route.id)));
      }
      return plans;
    } catch (e) {
      throw CacheException(message: 'Failed to load today\'s routes: $e');
    }
  }

  @override
  Future<List<RoutePlanModel>> fetchAllRoutes() async {
    try {
      final routes = await _dao.fetchAllRoutes();
      final plans = <RoutePlanModel>[];
      for (final route in routes) {
        plans.add(route.toModel(await _stopsFor(route.id)));
      }
      return plans;
    } catch (e) {
      throw CacheException(message: 'Failed to load all routes: $e');
    }
  }

  @override
  Future<RoutePlanModel?> getRoute(String routeId) async {
    try {
      final route = await _dao.getRoute(routeId);
      if (route == null) return null;
      return route.toModel(await _stopsFor(routeId));
    } catch (e) {
      throw CacheException(message: 'Failed to load route: $e');
    }
  }

  Future<List<RouteStop>> _stopsFor(String routeId) async {
    final joined = await _dao.fetchStopsWithDepots(routeId);
    return joined.map((row) => row.toModel()).toList();
  }

  @override
  Future<void> updateRouteStatus(String routeId, RouteStatus status) async {
    try {
      await _dao.updateRouteStatus(routeId, status.name);
    } catch (e) {
      throw CacheException(message: 'Failed to update route status: $e');
    }
  }

  @override
  Future<void> updateStopStatus(
    String stopId, {
    required VisitStatus status,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  }) async {
    try {
      await _dao.updateStopStatus(
        stopId,
        status: status.name,
        actualArrival: actualArrival,
        actualDeparture: actualDeparture,
      );
    } catch (e) {
      throw CacheException(message: 'Failed to update stop status: $e');
    }
  }

  /// Stores the depot rows the route feed sent with the plans.
  ///
  /// **Behaviour change (ADR-011), reversing the T1.5 decision.** T1.5 made
  /// this method apply two attributes onto depots the *directory* already
  /// had, and skip anything it did not — on the reasoning that `depots` is
  /// the single source of truth and route sync must not invent a row.
  ///
  /// That reasoning was right about ownership and wrong about availability. The
  /// route feed and the depot feed are separate endpoints with separate
  /// scopes, so "the directory has not pulled this depot yet" is the normal
  /// case, not the exception — and the consequences were severe: the stop's
  /// foreign key aborted the entire route write, and once that was removed an
  /// inner join would have hidden the stop instead.
  ///
  /// The feed already carries everything a stop needs to render, so it is
  /// stored as-is in its own flat table. Nothing is skipped, nothing is
  /// invented, and the depot directory is left entirely alone.
  @override
  Future<void> upsertDepots(List<DepotStopInfoModel> depots) async {
    try {
      await _dao.upsertRouteDepots(
        depots.map((c) => c.toRouteDepotCompanion()).toList(),
      );
      // A count, never an identifier (`docs/skills/security.md` §10). Worth recording
      // because a stop rendering as its bare depot id means this number came
      // back short — the feed omitted a depot it is contracted to send.
      _logger
          .debug('route_sync.depots_stored', fields: {'count': depots.length});
    } catch (e) {
      throw CacheException(message: 'Failed to upsert route depots: $e');
    }
  }

  @override
  Future<void> upsertRoutes(List<RoutePlanModel> routes) async {
    try {
      await _dao.upsertRoutesWithStops(
        routes
            .map((r) => RouteWithStops(r.toCompanion(), r.toStopCompanions()))
            .toList(),
      );
    } catch (e) {
      throw CacheException(message: 'Failed to upsert routes: $e');
    }
  }

  @override
  Future<DateTime?> getLastSyncedAt(String entity) async {
    try {
      return await _dao.getLastSyncedAt(entity);
    } catch (e) {
      throw CacheException(message: 'Failed to read sync cursor: $e');
    }
  }

  @override
  Future<void> setLastSyncedAt(String entity, DateTime at) async {
    try {
      await _dao.setLastSyncedAt(entity, at);
    } catch (e) {
      throw CacheException(message: 'Failed to write sync cursor: $e');
    }
  }
}
