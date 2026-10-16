import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';

/// A mocked GPS position must never carry a check-in in a release build.
///
/// The policy used to default `blockOnMockLocation: false` in **every** build,
/// so a shipped app accepted a fake-location provider with only a warning.
void main() {
  const service = FraudDetectionService();

  CheckInValidation validateMocked(FraudPolicy policy) =>
      service.validateCheckIn(
        insideGeofence: true,
        accuracyMeters: 5,
        isMocked: true,
        vpnDetected: false,
        policy: policy,
      );

  test('the release constant is the one Flutter calls kReleaseMode', () {
    expect(kFraudPolicyReleaseBuild, kReleaseMode);
    expect(const FraudPolicy().isReleaseBuild, kReleaseMode);
  });

  group('in a release build', () {
    const release = FraudPolicy(isReleaseBuild: true);

    test('mock location is blocked by default', () {
      expect(release.blockOnMockLocation, isTrue);

      final v = validateMocked(release);

      expect(v.allowed, isFalse);
      expect(v.integrityReasons, isNotEmpty);
      expect(v.canOverrideWithReason, isFalse,
          reason: 'a written reason can never answer "is this position real"');
    });

    test('mock location is blocked even if a caller asks to allow it', () {
      const permissive =
          FraudPolicy(isReleaseBuild: true, blockOnMockLocation: false);

      expect(permissive.blockOnMockLocation, isTrue);
      expect(validateMocked(permissive).allowed, isFalse);
    });

    test('a genuine position still checks in', () {
      final v = service.validateCheckIn(
        insideGeofence: true,
        accuracyMeters: 5,
        isMocked: false,
        vpnDetected: false,
        policy: release,
      );

      expect(v.allowed, isTrue);
    });
  });

  group('in a non-release build (the debug allowance)', () {
    const debug = FraudPolicy(isReleaseBuild: false);

    test('mock location is tolerated by default, with a warning', () {
      expect(debug.blockOnMockLocation, isFalse);

      final v = validateMocked(debug);

      expect(v.allowed, isTrue);
      expect(v.warnings, isNotEmpty,
          reason: 'still recorded as a fraud-trail warning');
    });

    test('and can still be made strict', () {
      const strict =
          FraudPolicy(isReleaseBuild: false, blockOnMockLocation: true);

      expect(validateMocked(strict).allowed, isFalse);
    });
  });
}
