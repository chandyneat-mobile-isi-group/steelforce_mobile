import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';
import 'package:steelforce/features/my_visits/domain/services/stop_distance_sorter.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_all_routes.dart';
import 'package:steelforce/features/my_visits/domain/usecases/watch_all_routes.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/stop_dashboard_state.dart';
import 'package:steelforce/features/my_visits/presentation/models/today_stop.dart';

/// Drives the Stop Dashboard: watches every synced route ([WatchAllRoutes]),
/// shows the **selected day's** stops (default today), and orders them
/// **nearest-first** by live GPS distance — delegating the ordering to the
/// domain [StopDistanceSorter] so no sort/distance logic lives in the UI.
///
/// Resilient to GPS: if location is denied or no fix arrives within
/// [_fixTimeout] (emulator / timeout / failure), it falls back to the planned
/// order and flags `locationUnavailable` — the dashboard always renders and the
/// full visit workflow stays usable offline.
class StopDashboardCubit extends Cubit<StopDashboardState> {
  StopDashboardCubit({
    required WatchAllRoutes watchAllRoutes,
    required FetchAllRoutes fetchAllRoutes,
    required LocationTrackingService locationService,
    required StopDistanceSorter sorter,
  })  : _watchAllRoutes = watchAllRoutes,
        _fetchAllRoutes = fetchAllRoutes,
        _locationService = locationService,
        _sorter = sorter,
        super(const StopDashboardLoading());

  final WatchAllRoutes _watchAllRoutes;
  final FetchAllRoutes _fetchAllRoutes;
  final LocationTrackingService _locationService;
  final StopDistanceSorter _sorter;

  StreamSubscription<List<RoutePlan>>? _routesSub;
  StreamSubscription<LocationSample>? _positionSub;
  Timer? _fixTimeoutTimer;

  /// Re-sort only after moving this far — keeps the list stable, saves battery.
  static const double _resortThresholdMeters = 50;

  /// If no GPS fix lands in this window, fall back to planned order.
  static const Duration _fixTimeout = Duration(seconds: 8);

  List<RoutePlan> _routes = const [];
  List<TodayStop> _sorted = const [];
  LocationSample? _position;
  LocationSample? _lastSortPosition;
  StopFilter _filter = StopFilter.all;
  String _query = '';
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _locating = true;
  bool _locationUnavailable = false;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _routesSub = _watchAllRoutes(const NoParams()).listen(
      _onRoutes,
      onError: (Object e) => emit(StopDashboardError(e.toString())),
    );

    final granted = await _locationService.ensurePermission();
    if (!granted) {
      _locationUnavailable = true;
      _locating = false;
      _emitLoaded();
      return;
    }
    _positionSub = _locationService
        .observe(distanceFilterMeters: 25)
        .listen(_onPosition, onError: (Object _) {});
    // Emulator / slow fix / service failure: don't hang on "locating" forever —
    // fall back to planned order, but keep listening so a late fix still upgrades.
    _fixTimeoutTimer = Timer(_fixTimeout, () {
      if (_position == null) {
        _locationUnavailable = true;
        _locating = false;
        _emitLoaded();
      }
    });
  }

  /// Re-reads all routes from the local store — sync writes through the data
  /// source, which the live watch stream doesn't observe, so the dashboard
  /// calls this when a sync reports success.
  Future<void> reload() async {
    final result = await _fetchAllRoutes(const NoParams());
    result.when(success: _onRoutes, failure: (_) {});
  }

  void setSelectedDate(DateTime date) {
    final day = DateUtils.dateOnly(date);
    if (DateUtils.isSameDay(day, _selectedDate)) return;
    _selectedDate = day;
    _rebuild();
    _emitLoaded();
  }

  void setFilter(StopFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    if (state is StopDashboardLoaded) _emitLoaded();
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    if (state is StopDashboardLoaded) _emitLoaded();
  }

  void _onRoutes(List<RoutePlan> routes) {
    _routes = routes;
    _rebuild();
    _emitLoaded();
  }

  void _onPosition(LocationSample sample) {
    _fixTimeoutTimer?.cancel();
    final movedEnough = _lastSortPosition == null ||
        GeofenceService.distanceMeters(
              _lastSortPosition!.latitude,
              _lastSortPosition!.longitude,
              sample.latitude,
              sample.longitude,
            ) >=
            _resortThresholdMeters;

    _position = sample;
    _locating = false;
    _locationUnavailable = false; // a fix arrived — upgrade from planned order

    if (movedEnough) {
      _lastSortPosition = sample;
      _rebuild();
    }
    _emitLoaded();
  }

  /// Builds the selected day's stops (from any routes on that day), delegates
  /// ordering to [StopDistanceSorter], then re-attaches route context.
  void _rebuild() {
    final ctx = <String, ({String routeId, String routeName})>{};
    final stops = <RouteStop>[];
    final today = DateUtils.dateOnly(DateTime.now());

    for (final route in _routes) {
      if (!DateUtils.isSameDay(route.visitDate, _selectedDate)) continue;
      final isOverdue = route.visitDate.isBefore(today);
      for (final stop in route.stops) {
        ctx[stop.id] = (routeId: route.id, routeName: route.name.tr);
        // Auto-correct statuses for past (overdue) dates:
        //   pending   → missed   (never started)
        //   checkedIn → checkedOut (left open, treat as completed)
        if (isOverdue) {
          final corrected = switch (stop.status) {
            VisitStatus.pending => VisitStatus.missed,
            VisitStatus.checkedIn => VisitStatus.checkedOut,
            _ => stop.status,
          };
          stops.add(corrected != stop.status
              ? stop.copyWith(status: corrected)
              : stop);
        } else {
          stops.add(stop);
        }
      }
    }

    final ranked = _sorter.sort(
      stops,
      latitude: _position?.latitude,
      longitude: _position?.longitude,
    );

    _sorted = [
      for (final r in ranked)
        TodayStop(
          stop: r.stop,
          routeId: ctx[r.stop.id]!.routeId,
          routeName: ctx[r.stop.id]!.routeName,
          distanceMeters: r.distanceMeters,
        ),
    ];
  }

  void _emitLoaded() {
    emit(StopDashboardLoaded(
      stops: _sorted,
      allRoutes: _routes,
      selectedDate: _selectedDate,
      filter: _filter,
      query: _query,
      position: _position,
      locating: _locating,
      locationUnavailable: _locationUnavailable,
    ));
  }

  @override
  Future<void> close() {
    _fixTimeoutTimer?.cancel();
    _routesSub?.cancel();
    _positionSub?.cancel();
    _locationService.stopObserving();
    return super.close();
  }
}
