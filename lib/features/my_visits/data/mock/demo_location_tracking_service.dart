/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// GPS for a demo build: a fixed position at the first stop of today's demo
/// route, with no permission prompt and no radio.
///
/// A presenter is not standing in a Phnom Penh steel yard, and a laptop
/// browser may have no location at all. Without this, the dashboard would
/// sort stops from wherever the presenter happens to be, and the browser's
/// location prompt would interrupt sign-in and every check-in. The check-in
/// verdict itself is placed on each stop's own pin by
/// `kUseStaticCheckInPosition` (`outlet_location_source.dart`), which is also
/// on in a demo build — this service only stops the hardware being asked.
library;

import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';

class DemoLocationTrackingService
    implements LocationTrackingService, LocationFixProvider {
  DemoLocationTrackingService({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// A good outdoor fix: inside every accuracy rule the check-in applies.
  static const double accuracyMeters = 8;

  static DemoDepot get _anchor => DemoSeed.todayStops.first;

  LocationSample sample(String routeId) => LocationSample(
        id: 'demo-fix-${_clock().microsecondsSinceEpoch}',
        routeId: routeId,
        latitude: _anchor.latitude,
        longitude: _anchor.longitude,
        accuracyMeters: accuracyMeters,
        speedMps: 0,
        headingDegrees: 0,
        altitudeMeters: 12,
        timestamp: _clock(),
        isMocked: false,
      );

  @override
  Future<bool> ensurePermission({bool background = false}) async => true;

  @override
  Stream<LocationSample> track(String routeId) => Stream.value(sample(routeId));

  @override
  Stream<LocationSample> observe({int distanceFilterMeters = 25}) =>
      Stream.value(sample('stop-dashboard'));

  @override
  Future<void> stopObserving() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<LocationAvailability> checkAvailability({bool request = true}) async =>
      LocationAvailability.available;

  @override
  Future<LocationSample?> lastKnownFix({required Duration maxAge}) async =>
      sample('last-known');

  @override
  Future<LocationSample?> currentFix({
    required bool precise,
    required Duration timeout,
  }) async =>
      sample('one-shot');

  @override
  Stream<bool> serviceEnabledChanges() => const Stream<bool>.empty();

  @override
  Future<bool> openLocationSettings() async => false;

  @override
  Future<bool> openAppSettings() async => false;
}
