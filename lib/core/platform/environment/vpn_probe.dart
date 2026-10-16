/// Platform-selected VPN heuristic backing `FraudDetectionService`.
///
/// Both sides expose `Future<bool> probeVpnInterfaces()`. Mobile inspects
/// network interfaces; web always reports false because browsers cannot see
/// them — read `vpn_probe_web.dart` before relying on this on web, it carries a
/// release-gate note.
library;

export 'vpn_probe_web.dart' if (dart.library.io) 'vpn_probe_native.dart';
