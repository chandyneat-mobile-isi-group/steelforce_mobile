import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/platform/environment/runtime_environment_native.dart';

/// Simulator detection, pinned against **real paths** taken from a booted
/// simulator (`xcrun simctl get_app_container`) and a physical device bundle.
///
/// ## The bug this exists to prevent recurring
///
/// The first implementation checked only `SIMULATOR_DEVICE_NAME`. Those
/// variables are set for processes launched *through* `simctl` — which is why
/// `xcrun simctl spawn booted /usr/bin/env` shows them — but a Flutter app is
/// launched by the simulator's SpringBoard and inherits none of them.
///
/// The result: detection returned false on the Simulator, the factory handed
/// out the real camera, and iOS answered with its own "Camera not available"
/// alert. The whole mock system was inert exactly where it was needed.
///
/// The filesystem is the signal that survives however the process was
/// launched, so these tests pin the path shapes rather than the environment.
void main() {
  /// Verbatim from `xcrun simctl get_app_container booted <bundle-id>`.
  const simulatorBundle =
      '/Users/chandyneat/Library/Developer/CoreSimulator/Devices/'
      '38935796-9E59-4ED9-B188-9A920CD2D81E/data/Containers/Bundle/'
      'Application/BE824812-B7F9-4DA8-A14B-BF8CB31DC10D/Runner.app';

  /// Verbatim from `... get_app_container booted <bundle-id> data` — what
  /// `HOME` resolves to inside the app.
  const simulatorHome =
      '/Users/chandyneat/Library/Developer/CoreSimulator/Devices/'
      '38935796-9E59-4ED9-B188-9A920CD2D81E/data/Containers/Data/'
      'Application/4DCB74C1-AF15-4CD4-A589-B109C50017C6';

  /// Where a real handset puts an installed app.
  const deviceBundle = '/private/var/containers/Bundle/Application/'
      'BE824812-B7F9-4DA8-A14B-BF8CB31DC10D/Runner.app';

  const deviceHome = '/private/var/mobile/Containers/Data/Application/'
      '4DCB74C1-AF15-4CD4-A589-B109C50017C6';

  group('a simulator path is recognised', () {
    test('the app bundle, which is what resolvedExecutable points into', () {
      expect(looksLikeSimulatorPath('$simulatorBundle/Runner'), isTrue);
    });

    test('the sandboxed HOME', () {
      expect(looksLikeSimulatorPath(simulatorHome), isTrue);
    });

    test('casing of the developer home directory does not matter', () {
      expect(
        looksLikeSimulatorPath(
            '/users/SomeOne/library/developer/coresimulator/Devices/x'),
        isTrue,
      );
    });
  });

  group('a physical device path is not', () {
    test('the app bundle', () {
      expect(looksLikeSimulatorPath('$deviceBundle/Runner'), isFalse,
          reason: 'a real device given the stand-in would silently upload '
              'placeholder images as depot evidence');
    });

    test('the sandboxed HOME', () {
      expect(looksLikeSimulatorPath(deviceHome), isFalse);
    });

    test('an empty or unrelated path', () {
      expect(looksLikeSimulatorPath(''), isFalse);
      expect(
          looksLikeSimulatorPath('/var/mobile/Applications/Runner'), isFalse);
    });
  });

  test('the host running these tests is not an iOS simulator', () {
    expect(isIosSimulator, isFalse);
    expect(isAndroidEmulator, isFalse);
  });
}
