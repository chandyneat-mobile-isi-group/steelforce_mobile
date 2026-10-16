import 'dart:math';

import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';

class GeofenceCheckResult {
  const GeofenceCheckResult(
      {required this.insideGeofence,
      required this.distanceMeters,
      required this.radiusMeters,
      this.locationKnown = true});
  final bool insideGeofence;
  final double distanceMeters;
  final double radiusMeters;

  /// False when the depot has no captured position, in which case
  /// [insideGeofence] and [distanceMeters] mean nothing.
  ///
  /// This is a third outcome, not a failure: the rep is not outside the
  /// geofence, there is simply no geofence to be outside of. A caller should
  /// let the visit proceed and capture the shop's location while it is there,
  /// rather than blocking a rep who is standing in the right place because
  /// nobody has ever recorded where that is.
  final bool locationKnown;
}

/// Pure, no I/O, unit-testable — mirrors `lead`'s `pipeline_rules.dart` shape
/// (a small top-level-function file, not a DI-registered service) since
/// there's nothing here to swap or mock.
class GeofenceService {
  const GeofenceService._();

  static const _earthRadiusMeters = 6371000.0;

  /// Haversine great-circle distance between two lat/lng points, in meters.
  static double distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  static GeofenceCheckResult evaluate({
    required double repLatitude,
    required double repLongitude,
    required DepotStopInfo depot,
  }) {
    final radius = depot.geofenceRadiusMeters;

    // Measuring against (0, 0) would report ~10 000 km and fail every check-in
    // at a shop nobody has geotagged yet.
    if (!depot.hasCoordinates) {
      return GeofenceCheckResult(
          insideGeofence: false,
          distanceMeters: double.nan,
          radiusMeters: radius,
          locationKnown: false);
    }

    final distance = distanceMeters(
        repLatitude, repLongitude, depot.latitude, depot.longitude);
    return GeofenceCheckResult(
        insideGeofence: distance <= radius,
        distanceMeters: distance,
        radiusMeters: radius);
  }
}
