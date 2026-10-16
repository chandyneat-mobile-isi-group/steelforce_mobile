import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';

/// Abstracts the actual GPS hardware/permission/foreground-service
/// mechanics away from the rest of the feature — [GeolocatorTrackingService]
/// is the real implementation.
abstract interface class LocationTrackingService {
  /// Requests location permission, escalating to background ("always") if
  /// [background] is true — called right before "Start Day", matching the
  /// staged-permission-request pattern the platforms expect.
  Future<bool> ensurePermission({bool background = false});

  /// Starts (or returns the existing) continuous GPS stream for [routeId],
  /// backed by a real Android foreground service / iOS background mode so
  /// it keeps running with the screen off or the app backgrounded.
  Stream<LocationSample> track(String routeId);

  /// Lightweight, **foreground-only** position stream for UI that needs the
  /// user's location while a screen is open — e.g. the Stop Dashboard's
  /// nearest-first sort. Unlike [track], it starts **no** foreground service /
  /// persistent notification and uses a larger [distanceFilterMeters] to
  /// conserve battery (only emits after meaningful movement). Independent of
  /// the route-scoped [track]/[stop] lifecycle; released via [stopObserving].
  Stream<LocationSample> observe({int distanceFilterMeters = 25});

  /// Stops the [observe] stream (no-op if not observing).
  Future<void> stopObserving();

  Future<void> stop();
}
