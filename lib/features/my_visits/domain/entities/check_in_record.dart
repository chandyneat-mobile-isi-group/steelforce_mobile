import 'package:equatable/equatable.dart';

class CheckInRecord extends Equatable {
  const CheckInRecord({
    required this.id,
    required this.stopId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.distanceFromDepotMeters,
    required this.isMocked,
    this.overrideReason,
    this.routeId,
  });

  final String id;
  final String stopId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double distanceFromDepotMeters;
  final bool isMocked;

  /// What the rep wrote when checking in from outside the geofence.
  ///
  /// Null on an ordinary check-in, and the two are meaningfully different on
  /// the server: an `OutsideGeofence` verdict with no reason is a rep who was
  /// not there, one with a reason is a rep who said why. Carried on this row
  /// rather than as a separate note so the reason and the verdict it explains
  /// are the same record.
  final String? overrideReason;

  /// The route the stop is on. Optional: the server uses it to refuse a stale
  /// stop quickly.
  final String? routeId;

  @override
  List<Object?> get props => [
        id,
        stopId,
        timestamp,
        latitude,
        longitude,
        accuracyMeters,
        distanceFromDepotMeters,
        isMocked,
        overrideReason,
        routeId,
      ];
}
