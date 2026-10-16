import 'dart:convert';
import 'package:http/http.dart' as http;

/// Web: VPN detection is not natively possible from a browser via OS interfaces.
/// To close the security gap mentioned in ADR-010, this queries a lightweight
/// IP intelligence API to check if the user's IP belongs to a VPN/Datacenter.
Future<bool> probeVpnInterfaces() async {
  try {
    // We request the 'proxy' (VPNs/TOR) and 'hosting' (Datacenters) fields.
    final uri = Uri.parse('http://ip-api.com/json/?fields=proxy,hosting');
    final response = await http.get(uri).timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final bool isProxy = data['proxy'] == true;
      final bool isHosting = data['hosting'] == true;

      // If the IP is flagged as a proxy/VPN or a datacenter, block it.
      return isProxy || isHosting;
    }

    // Fallback to false if the API fails or rate-limits
    return false;
  } catch (_) {
    // Fail securely (false) if offline or network blocks the request
    return false;
  }
}
