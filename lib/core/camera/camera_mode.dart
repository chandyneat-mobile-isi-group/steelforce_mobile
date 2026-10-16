import 'package:flutter/foundation.dart';
import 'package:steelforce/core/platform/environment/runtime_environment.dart';

/// Which camera implementation the app runs against.
///
/// Mirrors [DataSourceMode]: one `--dart-define` switch rather than a
/// scattering of commented-out lines in each feature.
///
/// ```
/// flutter run                                    # auto (the default)
/// flutter run --dart-define=CAMERA_MODE=mock     # force the stand-in
/// flutter run --dart-define=CAMERA_MODE=real     # force the device camera
/// ```
enum CameraMode {
  /// Decide from the runtime environment. **The default**, so a physical
  /// device is never accidentally left on placeholder images.
  auto,

  /// Always the device camera.
  real,

  /// Always the bundled test images.
  mock;

  static CameraMode fromName(String raw) => switch (raw.trim().toLowerCase()) {
        'mock' => CameraMode.mock,
        'real' => CameraMode.real,
        // An unrecognised value falls back to `auto` rather than throwing at
        // startup: a typo in a launch config should not stop the app booting,
        // and `auto` is the safe answer on every platform.
        _ => CameraMode.auto,
      };
}

/// Resolves the configured mode against the current environment.
abstract final class CameraConfig {
  static const String _raw =
      String.fromEnvironment('CAMERA_MODE', defaultValue: 'auto');

  /// What the developer asked for, before the environment is consulted.
  static CameraMode get requested => CameraMode.fromName(_raw);

  /// Whether the stand-in camera should be used.
  ///
  /// Under [CameraMode.auto] this is true **only** on the iOS Simulator, which
  /// has no camera hardware at all. Every physical device — and the Android
  /// emulator, whose emulated camera works — gets the real implementation.
  ///
  /// Never in a release build: the stand-in returns synthetic images, and a
  /// visit-proof photo is evidence the backend relies on.
  static bool get useMock => kReleaseMode
      ? false
      : switch (requested) {
          CameraMode.mock => true,
          CameraMode.real => false,
          CameraMode.auto => isIosSimulator || isAndroidEmulator,
        };

  /// Whether the mock is active *because someone asked for it* rather than
  /// because the hardware is absent. Surfaced in the developer indicator so a
  /// forced mock on a real handset is never mistaken for automatic behaviour.
  static bool get isForced => requested == CameraMode.mock;
}
