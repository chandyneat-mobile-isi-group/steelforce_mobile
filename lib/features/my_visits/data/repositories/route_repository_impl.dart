import 'dart:async';

import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';

class RouteRepositoryImpl implements RouteRepository {
  RouteRepositoryImpl(this._local);
  final RouteLocalDataSource _local;

  /// Broadcast hub for live route updates. Mutations push a fresh local
  /// snapshot here so any active [watchTodayRoutes] listener updates instantly.
  final StreamController<List<RoutePlan>> _routesController =
      StreamController<List<RoutePlan>>.broadcast();

  /// Same idea as [_routesController], for [watchAllRoutes] listeners.
  final StreamController<List<RoutePlan>> _allRoutesController =
      StreamController<List<RoutePlan>>.broadcast();

  @override
  ResultFuture<List<RoutePlan>> fetchTodayRoutes() async {
    try {
      return Success(await _local.fetchTodayRoutes());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<RoutePlan>> fetchAllRoutes() async {
    try {
      return Success(await _local.fetchAllRoutes());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  Stream<List<RoutePlan>> watchTodayRoutes() =>
      _watch(_routesController, _local.fetchTodayRoutes);

  @override
  Stream<List<RoutePlan>> watchAllRoutes() =>
      _watch(_allRoutesController, _local.fetchAllRoutes);

  /// Emits an immediate local snapshot, then every subsequent broadcast.
  ///
  /// The obvious `async*` version of this —
  /// `yield await read(); yield* controller.stream;` — had a silent data-loss
  /// window: a generator only reaches its `yield*` *after* the initial `await`
  /// completes, so for the duration of that database read nothing was
  /// subscribed to [controller]. Any mutation landing in that window hit the
  /// `hasListener` guard in the `_broadcast*` methods and was dropped for good,
  /// leaving the dashboard showing stale or empty content until some unrelated
  /// event happened to retrigger it.
  ///
  /// Subscribing to [controller] *before* starting the read closes that window.
  /// A broadcast arriving mid-read wins over the initial snapshot, since it is
  /// by definition the newer state — `_hasLiveValue` enforces that ordering
  /// rather than letting a slow read overwrite fresh data.
  Stream<List<RoutePlan>> _watch(
    StreamController<List<RoutePlan>> controller,
    Future<List<RoutePlan>> Function() read,
  ) {
    late StreamController<List<RoutePlan>> out;
    StreamSubscription<List<RoutePlan>>? upstream;
    var hasLiveValue = false;

    out = StreamController<List<RoutePlan>>(
      onListen: () {
        upstream = controller.stream.listen(
          (routes) {
            hasLiveValue = true;
            if (!out.isClosed) out.add(routes);
          },
          onError: (Object e, StackTrace s) {
            if (!out.isClosed) out.addError(e, s);
          },
        );

        // Initial snapshot. A CacheException surfaces as a stream error, which
        // the cubit maps to RouteDashboardError — same contract as before.
        read().then(
          (routes) {
            if (!out.isClosed && !hasLiveValue) out.add(routes);
          },
          onError: (Object e, StackTrace s) {
            if (!out.isClosed) out.addError(e, s);
          },
        );
      },
      onCancel: () async => upstream?.cancel(),
    );

    return out.stream;
  }

  /// Re-read the local cache and broadcast it to listeners. Called after any
  /// mutation so open screens (e.g. the dashboard) reflect the change live.
  Future<void> _broadcastTodayRoutes() async {
    if (!_routesController.hasListener) return;
    try {
      _routesController.add(await _local.fetchTodayRoutes());
    } on CacheException {
      // Keep the last good snapshot on a transient read error.
    }
  }

  /// Same idea as [_broadcastTodayRoutes], for [watchAllRoutes] listeners.
  Future<void> _broadcastAllRoutes() async {
    if (!_allRoutesController.hasListener) return;
    try {
      _allRoutesController.add(await _local.fetchAllRoutes());
    } on CacheException {
      // Keep the last good snapshot on a transient read error.
    }
  }

  @override
  ResultFuture<RoutePlan> getRoute(String routeId) async {
    try {
      final route = await _local.getRoute(routeId);
      if (route == null) {
        return const Failed(CacheFailure(message: 'Route not found.'));
      }
      return Success(route);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  Future<void> notifyStopsChanged() async {
    await _broadcastTodayRoutes();
    await _broadcastAllRoutes();
  }

  @override
  ResultFuture<void> updateRouteStatus(
      String routeId, RouteStatus status) async {
    try {
      await _local.updateRouteStatus(routeId, status);
      unawaited(_broadcastTodayRoutes());
      unawaited(_broadcastAllRoutes());
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateStopStatus(
    String stopId, {
    required VisitStatus status,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  }) async {
    try {
      await _local.updateStopStatus(
        stopId,
        status: status,
        actualArrival: actualArrival,
        actualDeparture: actualDeparture,
      );
      unawaited(_broadcastTodayRoutes());
      unawaited(_broadcastAllRoutes());
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }
}
