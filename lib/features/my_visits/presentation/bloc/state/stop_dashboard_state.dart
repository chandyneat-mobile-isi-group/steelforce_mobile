import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/core/utils/text_normalization.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/presentation/models/today_stop.dart';

/// Status filter for the Stop Dashboard list.
enum StopFilter { all, pending, checkedIn, completed, skipped }

sealed class StopDashboardState extends Equatable {
  const StopDashboardState();
  @override
  List<Object?> get props => [];
}

/// First frame — the screen shows skeletons (never a blank white screen).
final class StopDashboardLoading extends StopDashboardState {
  const StopDashboardLoading();
}

final class StopDashboardError extends StopDashboardState {
  const StopDashboardError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// The live dashboard. [stops] holds the **selected day's** stops sorted
/// nearest-first; the screen renders [visibleStops] (filter + search applied
/// here so widgets stay dumb). [allRoutes] backs the calendar's per-day
/// stop-count dots across every synced day.
final class StopDashboardLoaded extends StopDashboardState {
  const StopDashboardLoaded({
    required this.stops,
    required this.allRoutes,
    required this.selectedDate,
    required this.filter,
    required this.query,
    required this.position,
    required this.locating,
    required this.locationUnavailable,
  });

  /// Selected day's stops, sorted nearest-first (planned order until a GPS fix).
  final List<TodayStop> stops;

  /// Every synced route (all days) — for the calendar's per-day counts.
  final List<RoutePlan> allRoutes;
  final DateTime selectedDate;
  final StopFilter filter;
  final String query;
  final LocationSample? position;

  /// True until the first GPS fix arrives — drives the "locating…" hint.
  final bool locating;

  /// True when location can't be used (permission denied, GPS off, emulator,
  /// timeout, failure). The list falls back to planned order; distances hidden.
  final bool locationUnavailable;

  /// Total stops scheduled on [day] across all routes — the calendar dot count.
  int stopCountForDay(DateTime day) {
    var count = 0;
    for (final r in allRoutes) {
      if (DateUtils.isSameDay(r.visitDate, day)) count += r.stops.length;
    }
    return count;
  }

  bool _matchesFilter(TodayStop s) => switch (filter) {
        StopFilter.all => true,
        StopFilter.pending => s.stop.status == VisitStatus.pending ||
            s.stop.status == VisitStatus.enRoute ||
            s.stop.status == VisitStatus.arrived,
        StopFilter.checkedIn => s.stop.status == VisitStatus.checkedIn,
        StopFilter.completed => s.stop.status == VisitStatus.checkedOut,
        StopFilter.skipped => s.stop.status == VisitStatus.missed,
      };

  bool _matchesQuery(TodayStop s) {
    // Zero-width characters are stripped from both sides, because SAP embeds
    // them inside Khmer names as word-break hints and they are invisible on
    // screen — a rep reading a shop's name off the card and typing it back
    // would otherwise match nothing. This is the same normalisation
    // `DepotDao.browse` applies in SQL, which is what lets the claim below
    // (in-memory and on-disk search agree) actually hold.
    //
    // Phone normalisation is deliberately *not* applied here: unlike the
    // directory, this path does not search a phone column, so reducing a
    // phone-shaped term to digits could only lose matches against the address
    // and route name.
    final q = stripZeroWidth(query.trim()).toLowerCase();
    if (q.isEmpty) return true;
    final c = s.stop.depot;
    bool contains(String value) =>
        stripZeroWidth(value).toLowerCase().contains(q);
    // Matches the shop's name in *either* language, whichever the UI is
    // showing: a rep who knows a shop by its Khmer sign types that even while
    // the app is in English, and vice versa. `searchableValues` already spans
    // both plus the depot code.
    return c.searchableValues.any(contains) ||
        contains(c.address) ||
        contains(s.routeName);
  }

  /// Filter + search applied — what the list actually renders.
  List<TodayStop> get visibleStops =>
      stops.where((s) => _matchesFilter(s) && _matchesQuery(s)).toList();

  StopDashboardLoaded copyWith({
    List<TodayStop>? stops,
    List<RoutePlan>? allRoutes,
    DateTime? selectedDate,
    StopFilter? filter,
    String? query,
    LocationSample? position,
    bool? locating,
    bool? locationUnavailable,
  }) {
    return StopDashboardLoaded(
      stops: stops ?? this.stops,
      allRoutes: allRoutes ?? this.allRoutes,
      selectedDate: selectedDate ?? this.selectedDate,
      filter: filter ?? this.filter,
      query: query ?? this.query,
      position: position ?? this.position,
      locating: locating ?? this.locating,
      locationUnavailable: locationUnavailable ?? this.locationUnavailable,
    );
  }

  @override
  List<Object?> get props => [
        stops,
        allRoutes,
        selectedDate,
        filter,
        query,
        position,
        locating,
        locationUnavailable,
      ];
}
