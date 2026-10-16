import 'package:equatable/equatable.dart';

/// One GPS reading, captured continuously while a route is active (see
/// `LocationTrackingService`) — the raw trail a route's polyline and
/// anti-fraud checks are built from.
class LocationSample extends Equatable {
  const LocationSample({
    required this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedMps,
    required this.headingDegrees,
    required this.altitudeMeters,
    required this.timestamp,
    required this.isMocked,
  });

  final String id;
  final String routeId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedMps;
  final double headingDegrees;
  final double altitudeMeters;
  final DateTime timestamp;
  final bool isMocked;

  @override
  List<Object?> get props =>
      [id, routeId, latitude, longitude, timestamp, isMocked];
}
