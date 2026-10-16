import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:steelforce/features/order/domain/services/order_location_service.dart';

/// One-shot GPS capture for off-visit order entry, backed by `geolocator`
/// (already a dependency via `my_visits`). Foreground-only — no background
/// permission escalation needed for a single snapshot.
class GeolocatorOrderLocationService implements OrderLocationService {
  const GeolocatorOrderLocationService();

  @override
  Future<({double lat, double lng})?> captureOnce() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _log('[DepotRegistration][GPS] Location services are disabled');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    _log('[DepotRegistration][GPS] Permission before request: '
        '${permission.name}');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      _log('[DepotRegistration][GPS] Permission after request: '
          '${permission.name}');
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _log('[DepotRegistration][GPS] Location permission unavailable');
      return null;
    }

    try {
      final position = await _getPosition(LocationAccuracy.high);
      _log('[DepotRegistration][GPS] High-accuracy fix: '
          'accuracy=${position.accuracy}m');
      return (lat: position.latitude, lng: position.longitude);
    } catch (error) {
      // A high-accuracy (GPS) fix can take too long indoors. A network-backed
      // medium-accuracy position is still sufficient for the form's Cambodia
      // bounds validation, and prevents the button from failing silently.
      _log('[DepotRegistration][GPS] High-accuracy capture failed: '
          '$error. Retrying with medium accuracy.');
      try {
        final position = await _getPosition(LocationAccuracy.medium);
        _log('[DepotRegistration][GPS] Medium-accuracy fix: '
            'accuracy=${position.accuracy}m');
        return (lat: position.latitude, lng: position.longitude);
      } catch (fallbackError) {
        _log('[DepotRegistration][GPS] No position captured: '
            '$fallbackError');
        return null;
      }
    }
  }

  /// Diagnostics for debug builds only. `debugPrint` still reaches logcat and
  /// the device console in release, and a rep's position is PII
  /// (`docs/skills/security.md` §10), so coordinates are never logged.
  static void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<Position> _getPosition(LocationAccuracy accuracy) =>
      Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: const Duration(seconds: 20),
      );
}
