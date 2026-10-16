import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_dashboard_summary.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_all_routes.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/route_dashboard_state.dart';

/// Drives the dashboard off a live [WatchAllRoutes] stream: emits
/// [RouteDashboardLoading] (→ skeletons) until the first snapshot arrives, then
/// [RouteDashboardLoaded] on every update, and [RouteDashboardError] on a
/// stream error. Check-in/out anywhere in the app pushes through here live.
///
/// Backed by every locally-synced route (not just today's) since `state.routes`
/// feeds both the calendar's per-day route-count dots and date-selection
/// browsing in `RouteDashboardScreen` — both need routes for arbitrary days,
/// which a today-only stream can't provide.
class RouteDashboardCubit extends Cubit<RouteDashboardState> {
  RouteDashboardCubit({required WatchAllRoutes watchAllRoutes})
      : _watchAllRoutes = watchAllRoutes,
        super(const RouteDashboardLoading()) {
    _subscribe();
  }

  final WatchAllRoutes _watchAllRoutes;
  StreamSubscription<List<RoutePlan>>? _subscription;

  void _subscribe() {
    // A subscription that is open but hasn't delivered its first snapshot yet
    // is still perfectly good — let it finish. Tearing it down and starting
    // over (what every `load()` used to do) discarded an in-flight database
    // read, re-emitted RouteDashboardLoading — an extra full-screen skeleton
    // flash — and began a second identical read. On this screen `load()` fires
    // from the constructor, the sync-success listener and pull-to-refresh, so
    // under repeated sync events the dashboard could churn in Loading and never
    // settle.
    //
    // Note this deliberately does *not* skip when data is already on screen:
    // sync writes go through RouteSyncRepositoryImpl, which never reaches this
    // repository's broadcast controller, so a genuine re-read is the only way
    // pull-to-refresh sees post-sync data.
    final awaitingFirstSnapshot =
        _subscription != null && state is! RouteDashboardLoaded;
    if (awaitingFirstSnapshot) return;

    // Only flash skeletons when we don't already have data on screen.
    if (state is! RouteDashboardLoaded) emit(const RouteDashboardLoading());
    _subscription?.cancel();
    _subscription = _watchAllRoutes(const NoParams()).listen(
      (routes) => emit(RouteDashboardLoaded(
          routes: routes, summary: _summarize(_todayOnly(routes)))),
      onError: (Object e) => emit(RouteDashboardError(e.toString())),
    );
  }

  /// The summary cards (`stopsToday`, `completed`, `progress`, ...) are
  /// explicitly about *today* — [routes] now spans every synced day (needed
  /// for the calendar dots and date-selection), so it must be narrowed back
  /// down before summarizing or the cards would silently aggregate every
  /// day's stats together. Compares against the UTC calendar day — `visitDate`
  /// is UTC-anchored throughout this feature (see `RouteDao.fetchRoutesForDay`,
  /// the route feed) — comparing local `y/m/d`
  /// instead would misclassify "today" in any positive-UTC-offset zone.
  List<RoutePlan> _todayOnly(List<RoutePlan> routes) {
    final nowUtc = DateTime.now().toUtc();
    return routes
        .where((r) =>
            r.visitDate.year == nowUtc.year &&
            r.visitDate.month == nowUtc.month &&
            r.visitDate.day == nowUtc.day)
        .toList();
  }

  /// Re-attach the stream (re-reads the local cache) — used by pull-to-refresh
  /// after a sync. Keeps the current list visible instead of flashing skeletons.
  Future<void> load() async => _subscribe();

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  RouteDashboardSummary _summarize(List<RoutePlan> routes) {
    final allStops = routes.expand((r) => r.stops).toList();
    final completed =
        allStops.where((s) => s.status == VisitStatus.checkedOut).length;
    final missed = allStops.where((s) => s.status == VisitStatus.missed).length;

    var distanceKm = 0.0;
    var visitMinutes = 0;
    for (final route in routes) {
      for (var i = 0; i < route.stops.length; i++) {
        final stop = route.stops[i];
        if (stop.actualArrival != null && stop.actualDeparture != null) {
          visitMinutes +=
              stop.actualDeparture!.difference(stop.actualArrival!).inMinutes;
        }
        if (i > 0) {
          final prev = route.stops[i - 1].depot;
          distanceKm += GeofenceService.distanceMeters(
                prev.latitude,
                prev.longitude,
                stop.depot.latitude,
                stop.depot.longitude,
              ) /
              1000;
        }
      }
    }

    // Of the stops actually *attempted* (completed or missed), how many
    // succeeded. Deliberately not the same as `progress`, which measures how
    // far through the whole day's plan the rep is — early in the day progress
    // is low while success rate can still be 100%. These previously returned
    // the identical expression, which made the success-rate card meaningless.
    final attempted = completed + missed;

    return RouteDashboardSummary(
      stopsToday: allStops.length,
      completed: completed,
      remaining: allStops.length - completed - missed,
      missed: missed,
      progress: allStops.isEmpty ? 0 : completed / allStops.length,
      totalDistanceKm: distanceKm,
      drivingTimeMinutes: _estimateDrivingMinutes(distanceKm),
      visitTimeMinutes: visitMinutes,
      // ── Not derivable here, and deliberately not faked ──────────────────
      // Collections, order lines and their values live in `visit_collections`
      // / `visit_order_lines`, keyed by stopId, and `VisitRepository` only
      // exposes per-stop reads. Populating these from this cubit would mean
      // one fetch per stop (six queries each) on every stream emission — the
      // N+1 pattern AI_ENGINEERING_PLAYBOOK.md §9 forbids.
      //
      // Showing an invented revenue figure to a sales rep is worse than
      // showing zero, so these stay zero until the aggregate exists.
      // TODO(my-visits): add a batched `VisitRepository.fetchTotalsForStops(
      // List<String> stopIds)` returning collection/order/value sums in one
      // query, then feed it in here.
      totalCollections: 0,
      totalOrders: 0,
      totalSalesValue: 0,
      successRate: attempted == 0 ? 0 : completed / attempted,
    );
  }

  /// Rough driving time from the straight-line distance between consecutive
  /// stops. 25 km/h is a deliberately conservative blended city/provincial
  /// average for a field route; it is an *estimate* shown as such, not a
  /// tracked measurement. Replace with real telemetry once `location_samples`
  /// is aggregated per route.
  static const double _avgSpeedKmh = 25;

  int _estimateDrivingMinutes(double distanceKm) =>
      distanceKm <= 0 ? 0 : ((distanceKm / _avgSpeedKmh) * 60).round();
}
