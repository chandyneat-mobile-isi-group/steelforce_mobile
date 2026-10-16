import 'package:geolocator/geolocator.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/permissions/location_permission_service.dart';

/// `geolocator`-backed [LocationPermissionService].
///
/// No conditional-import split, unlike `core/notifications/push_*`. That split
/// exists because `flutter_local_notifications` has no web implementation and
/// its entrypoint imports `dart:io`, so merely importing it breaks a web build.
/// `geolocator` ships `geolocator_web` and compiles for every target this app
/// builds, so a split here would be ceremony with no failure behind it.
class GeolocatorLocationPermissionService implements LocationPermissionService {
  const GeolocatorLocationPermissionService(this._logger);

  final AppLogger _logger;

  @override
  Future<LocationPermissionStatus> status() async {
    try {
      // Checked first, and reported as its own state. A granted permission with
      // location services switched off still yields no position, and telling the
      // rep to "allow location access" then sends them to a screen where
      // everything already looks correct.
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermissionStatus.servicesDisabled;
      }
      return _map(await Geolocator.checkPermission());
    } catch (error) {
      _logger.warning('location.permission_check_failed',
          fields: {'error': error.runtimeType.toString()});
      return LocationPermissionStatus.unsupported;
    }
  }

  @override
  Future<LocationPermissionStatus> request() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        // Requesting here would return a permission the rep cannot use, and on
        // some platforms would not prompt at all. Reporting the real blocker
        // lets the dialog offer the settings route instead of a dead prompt.
        _logger.info('location.request_skipped_services_off');
        return LocationPermissionStatus.servicesDisabled;
      }

      final current = await Geolocator.checkPermission();
      // Already answered, and answered permanently. Re-requesting returns the
      // same value without showing anything — so do not spend a call implying
      // otherwise.
      if (current == LocationPermission.deniedForever) {
        return LocationPermissionStatus.deniedForever;
      }
      if (current == LocationPermission.whileInUse ||
          current == LocationPermission.always) {
        return _map(current);
      }

      final result = _map(await Geolocator.requestPermission());
      _logger
          .info('location.permission_result', fields: {'status': result.name});
      return result;
    } catch (error, stackTrace) {
      _logger.error('location.permission_request_failed',
          error: error, stackTrace: stackTrace);
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      // App settings, not location settings: a permanent denial is an
      // app-scoped decision, and the app's own page is where the rep can
      // actually reverse it.
      return await Geolocator.openAppSettings();
    } catch (error) {
      _logger.warning('location.open_settings_failed',
          fields: {'error': error.runtimeType.toString()});
      return false;
    }
  }

  LocationPermissionStatus _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always => LocationPermissionStatus.always,
        LocationPermission.whileInUse => LocationPermissionStatus.whileInUse,
        LocationPermission.denied => LocationPermissionStatus.denied,
        LocationPermission.deniedForever =>
          LocationPermissionStatus.deniedForever,
        // `unableToDetermine` is geolocator's "the platform did not say".
        // Treated as not-yet-asked so the rep still gets offered the prompt —
        // the alternative silently withholds a permission the app needs on the
        // strength of an inconclusive answer.
        LocationPermission.unableToDetermine =>
          LocationPermissionStatus.notDetermined,
      };
}
