import 'dart:io';

/// Android/iOS: scan active network interfaces for common VPN tunnel naming
/// patterns. Expanded to catch WireGuard, OpenVPN, IPSec, and enterprise VPNs.
Future<bool> probeVpnInterfaces() async {
  try {
    final interfaces = await NetworkInterface.list();
    return interfaces.any((i) {
      final name = i.name.toLowerCase();
      return name.startsWith('tun') || // OpenVPN / Standard Tun
          name.startsWith('tap') || // OpenVPN / Standard Tap
          name.startsWith('ppp') || // Point-to-Point
          name.startsWith('utun') || // macOS / iOS Tunnels
          name.startsWith('wg') || // WireGuard
          name.startsWith('wireguard') || // WireGuard (alt)
          name.startsWith('ipsec') || // IPSec
          name.startsWith('tailscale') || // Tailscale
          name.startsWith('wintun') || // Windows VPN Tun
          name.startsWith('warp') || // Cloudflare WARP
          name.startsWith('gpd') || // GlobalProtect
          name.contains('vpn'); // Generic fallback
    });
  } catch (e) {
    // If we cannot read the interfaces (e.g., missing permissions),
    // fail securely by assuming false rather than crashing.
    return false;
  }
}
