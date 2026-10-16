import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';

/// Presentation-only join of a [RouteStop] with the route it belongs to (name +
/// id) and the live distance from the rep's current location.
///
/// The Stop Dashboard is stop-first, but a stop only carries its `routeId`; the
/// route *name* lives on the parent [RoutePlan]. Flattening today's routes into
/// these view models keeps that context on each card without a domain change,
/// and keeps every coordinate on board so map navigation can be added later
/// with no model change.
class TodayStop extends Equatable {
  const TodayStop({
    required this.stop,
    required this.routeId,
    required this.routeName,
    this.distanceMeters,
  });

  final RouteStop stop;
  final String routeId;
  final String routeName;

  /// Straight-line (Haversine) distance from the rep's current location, or
  /// null while location is still being acquired.
  final double? distanceMeters;

  /// Estimated travel minutes at the 25 km/h blended field average used across
  /// this feature, or null when distance is unknown.
  int? get etaMinutes {
    final d = distanceMeters;
    if (d == null) return null;
    return ((d / 1000) / 25 * 60).clamp(1, 999).round();
  }

  TodayStop copyWith({double? distanceMeters}) => TodayStop(
        stop: stop,
        routeId: routeId,
        routeName: routeName,
        distanceMeters: distanceMeters ?? this.distanceMeters,
      );

  @override
  List<Object?> get props => [stop, routeId, routeName, distanceMeters];
}
