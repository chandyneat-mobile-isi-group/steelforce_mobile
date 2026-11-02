// TODO(release-gate): demo-only GPS, an anti-fraud bypass; must never be registered in a release mobile build (USE_MOCK_DATA=false).
//
// GPS for the static web demo: a fixed, good-quality fix at today's first
// demo depot, with no permission prompt and no radio.
//
// A presenter is not standing in a Phnom Penh steel yard, and a laptop
// browser may have no location or deny it. Without this, the browser's
// location prompt would interrupt every check-in, and a refused one would
// block check-out ("no location"). The check-in verdict itself is placed on
// each stop's own pin by `kUseStaticCheckInPosition`
// (`outlet_location_source.dart`), which a demo build also turns on — this
// service only keeps the hardware from being asked.
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_world.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';

class DemoLocationTrackingService
    implements LocationTrackingService, LocationFixProvider {
  DemoLocationTrackingService({DateTime Function() clock = DateTime.now})
      : _clock = clock;

  final DateTime Function() _clock;

  /// A good outdoor fix: inside every accuracy rule check-in applies.
  static const double accuracyMeters = 8;

  static MockVisitDepot get _anchor => MockVisitWorld.depots.first;

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
      Stream.value(sample('observe'));

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
