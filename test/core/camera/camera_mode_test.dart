import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/camera/camera_mode.dart';

/// How `--dart-define=CAMERA_MODE=…` is read.
///
/// The parsing is what stops a typo in a launch configuration from either
/// crashing the app at startup or — far worse — silently leaving a physical
/// device on placeholder images.
void main() {
  group('parsing', () {
    test('the three documented values', () {
      expect(CameraMode.fromName('auto'), CameraMode.auto);
      expect(CameraMode.fromName('real'), CameraMode.real);
      expect(CameraMode.fromName('mock'), CameraMode.mock);
    });

    test('case and surrounding whitespace do not matter', () {
      expect(CameraMode.fromName('  MOCK '), CameraMode.mock);
      expect(CameraMode.fromName('Real'), CameraMode.real);
    });

    test('anything unrecognised falls back to auto, never to mock', () {
      // The failure mode this prevents: a mistyped define leaving a shipped
      // build uploading placeholder images.
      for (final bad in const ['', 'mocked', 'fake', 'true', 'yes', 'REAL_']) {
        expect(CameraMode.fromName(bad), CameraMode.auto, reason: bad);
      }
    });
  });

  group('the default build', () {
    test('is auto — never a hardcoded mock', () {
      // No --dart-define is passed under `flutter test`, so this is what a
      // developer running `flutter run` gets.
      expect(CameraConfig.requested, CameraMode.auto);
    });

    test('auto does not force the mock, and reports it was not forced', () {
      expect(CameraConfig.isForced, isFalse);
    });

    test('on a non-simulator host, auto resolves to the real camera', () {
      // The test host is macOS, which is neither the iOS Simulator nor an
      // Android emulator — so auto must choose the real implementation. This
      // is the guard that a physical device is never given the stand-in.
      expect(CameraConfig.useMock, isFalse);
    });
  });
}
