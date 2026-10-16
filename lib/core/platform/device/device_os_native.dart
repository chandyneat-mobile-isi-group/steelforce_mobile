import 'dart:io';

/// Android/iOS/desktop: the OS name and version as the kernel reports it,
/// e.g. `Android 15` or `iOS 18.2`.
String? readOsVersion() {
  try {
    final name = switch (Platform.operatingSystem) {
      'android' => 'Android',
      'ios' => 'iOS',
      'macos' => 'macOS',
      'windows' => 'Windows',
      'linux' => 'Linux',
      final other => other,
    };
    final version = Platform.operatingSystemVersion.trim();
    return version.isEmpty ? name : '$name $version';
  } catch (_) {
    return null;
  }
}

/// The device's host name where the OS exposes one. Used as a fallback
/// [deviceName] so a session row reads "Pixel-8" rather than a bare GUID.
String? readHostName() {
  try {
    final host = Platform.localHostname.trim();
    return host.isEmpty ? null : host;
  } catch (_) {
    // Sandboxed iOS builds throw rather than return empty.
    return null;
  }
}
