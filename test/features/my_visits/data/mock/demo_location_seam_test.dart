import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_location_tracking_service.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/services/check_in_location_verifier.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/services/outlet_location_source.dart';

void main() {
  group('DemoLocationTrackingService', () {
    final clock = DateTime.utc(2026, 10, 14, 3);
    final service = DemoLocationTrackingService(clock: () => clock);
    final anchor = DemoSeed.todayStops.first;

    test('never asks for permission and reports location available', () async {
      expect(await service.ensurePermission(background: true), isTrue);
      expect(await service.checkAvailability(), LocationAvailability.available);
    });

    test('every read is a fresh, unmocked fix at today\'s first stop',
        () async {
      final reads = [
        await service.currentFix(
            precise: true, timeout: const Duration(seconds: 1)),
        await service.lastKnownFix(maxAge: const Duration(minutes: 2)),
        await service.observe().first,
        await service.track('demo-route-today').first,
      ];
      for (final fix in reads) {
        expect(fix, isNotNull);
        expect(fix!.latitude, anchor.latitude);
        expect(fix.longitude, anchor.longitude);
        expect(fix.isMocked, isFalse);
        expect(fix.timestamp, clock);
      }
    });

    test('its fix passes the check-in fraud rules', () {
      const policy = FraudPolicy();
      final validation = const FraudDetectionService().validateCheckIn(
        insideGeofence: true,
        accuracyMeters: DemoLocationTrackingService.accuracyMeters,
        isMocked: false,
        vpnDetected: false,
        policy: policy,
      );
      expect(validation.allowed, isTrue);
    });
  });

  group('check-in position seam', () {
    test('every demo stop verifies within the check-in radius', () async {
      // The rep stands where `staticCheckInPositionFor` puts them, measured
      // against the outlet source the check-in screen uses.
      final page = await DemoRouteRemoteDataSource(
        DemoNetwork(),
        DemoVisitLedger(),
      ).fetchInitial(
        scope: const RouteSyncScope(repId: 'r', territory: 'PP-NORTH'),
        page: 0,
        pageSize: 50,
      );

      for (final stop in page.routes.expand((r) => r.stops)) {
        final standIn = staticCheckInPositionFor(stop.depot);
        final verdict = CheckInLocationVerifier.verify(
          outlet: kCheckInOutletLocationSource.locationFor(stop.depot),
          deviceLatitude: standIn.latitude,
          deviceLongitude: standIn.longitude,
          fallbackRadiusMeters: kCheckInRadiusMeters,
        );
        expect(verdict.isWithinRadius, isTrue, reason: stop.depot.name);
        expect(verdict.distanceMeters, 0);
      }
    });

    // `flutter test` is a debug build, where the flag is already on through
    // `STATIC_CHECK_IN_POSITION`. This pins the demo half: run with
    // `--dart-define=USE_MOCK_DATA=true` to exercise it.
    test('is on in a demo build', () {
      expect(kUseStaticCheckInPosition, isTrue);
    }, skip: !DataSourceMode.useMocks);
  });
}
