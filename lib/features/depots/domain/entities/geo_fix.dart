/// A GPS fix captured on site.
class GeoFix {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime capturedAt;

  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
  });

  /// Rough Cambodia bounding box — rejects an emulator fix or a stale
  /// last-known location from another country.
  bool get isInsideCambodia =>
      latitude >= 9.9 &&
      latitude <= 14.7 &&
      longitude >= 102.3 &&
      longitude <= 107.7;

  String get display =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}
