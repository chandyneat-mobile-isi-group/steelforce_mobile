import 'dart:io';

/// True when running on the iOS Simulator.
///
/// ## Why this is not one environment-variable check
///
/// `SIMULATOR_DEVICE_NAME` and `SIMULATOR_UDID` are set for processes launched
/// *through* `simctl` — which is why `xcrun simctl spawn booted /usr/bin/env`
/// shows them. A Flutter app is launched by the simulator's SpringBoard
/// instead, and inherits none of them. Relying on that check alone sent the
/// real `UIImagePickerController` to a device with no camera, and iOS answered
/// with its own "Camera not available" alert.
///
/// The reliable signal is the **filesystem**: every simulator app lives under
/// `.../Library/Developer/CoreSimulator/Devices/<UDID>/...`, a path no
/// physical device has — its bundles sit under `/private/var/containers`. Both
/// the executable path and the app's home directory carry it.
///
/// Checked in cheapest-first order, and any one match is sufficient. Doing this
/// without `device_info_plus` keeps the dependency list unchanged for what is,
/// in the end, one boolean.
bool get isIosSimulator {
  if (!Platform.isIOS) return false;
  try {
    // The app bundle's own path. Present however the process was launched,
    // which is exactly what the environment variables are not.
    if (looksLikeSimulatorPath(Platform.resolvedExecutable)) return true;

    final env = Platform.environment;

    // The sandboxed home directory, likewise under CoreSimulator.
    final home = env['HOME'];
    if (home != null && looksLikeSimulatorPath(home)) return true;

    // Set only when launched through `simctl`. Kept as a cheap extra signal
    // rather than the sole one.
    return env.containsKey('SIMULATOR_DEVICE_NAME') ||
        env.containsKey('SIMULATOR_UDID');
  } on Object {
    // A sandboxed build can refuse these reads. Treating that as "physical" is
    // the safe default: a real device wrongly given the stand-in would silently
    // upload placeholder images as depot evidence.
    return false;
  }
}

/// True for a path inside a CoreSimulator device container.
///
/// Simulator app bundle:
/// `/Users/<you>/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Bundle/Application/<GUID>/Runner.app`
///
/// Physical device app bundle:
/// `/private/var/containers/Bundle/Application/<GUID>/Runner.app`
///
/// The `CoreSimulator` segment is what separates them, and it appears in both
/// the executable path and the sandboxed `HOME`. Verified against a booted
/// simulator via `xcrun simctl get_app_container`.
///
/// Case-insensitive because the developer's own home directory sits in the
/// middle of it and its casing is not ours to assume.
bool looksLikeSimulatorPath(String path) =>
    path.toLowerCase().contains('coresimulator');

bool get isMobilePlatform => Platform.isIOS || Platform.isAndroid;

/// True on the Android emulator.
///
/// **Deliberately always false.** Reading `Build.FINGERPRINT` needs
/// `device_info_plus`, and the emulator ships a working emulated camera that
/// `image_picker` drives correctly — so the real implementation is the right
/// one there, and adding a dependency to route around a camera that works
/// would be backwards. A developer who wants the mock anyway can ask for it:
/// `--dart-define=CAMERA_MODE=mock`.
bool get isAndroidEmulator => false;
