import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/platform/environment/vpn_probe.dart';

import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';

class CheckInValidation {
  const CheckInValidation({
    required this.allowed,
    required this.blockedReasons,
    required this.warnings,
    this.overridableReasons = const [],
    this.integrityReasons = const [],
  });

  final bool allowed;
  final List<String> blockedReasons;
  final List<String> warnings;

  /// Blocks a rep can answer for: outside the geofence, or a fix too coarse to
  /// judge. Both are statements about the *place*, and a place can have a
  /// legitimate explanation — a depot gate far from the office pin, a steel
  /// roof killing the fix.
  final List<String> overridableReasons;

  /// Blocks about whether the device is telling the truth — a mock location
  /// provider, a VPN. **Never overridable.** A free-text box cannot answer
  /// "is this position real", and letting it try would turn the one control
  /// that catches faked visits into a formality.
  final List<String> integrityReasons;

  /// True when a written reason could carry this check-in through.
  bool get canOverrideWithReason =>
      integrityReasons.isEmpty && overridableReasons.isNotEmpty;
}

/// Anti-fraud checks for check-in/out and the continuous location trail.
/// Every rule is individually gated by [FraudPolicy] so it can be relaxed
/// per business rule without touching this detection logic (per the
/// "modular so future business rules can enable/disable/relax" requirement).
class FraudDetectionService {
  const FraudDetectionService();

  /// Combines geofence + accuracy + mock-location into one pass/fail with
  /// specific reasons — never a generic "can't check in".
  CheckInValidation validateCheckIn({
    required bool insideGeofence,
    required double accuracyMeters,
    required bool isMocked,
    required bool vpnDetected,
    required FraudPolicy policy,
  }) {
    final overridable = <String>[];
    final integrity = <String>[];
    final warnings = <String>[];

    if (!insideGeofence) {
      overridable.add("You're outside the depot's geofence.");
    }
    if (accuracyMeters > policy.maxAccuracyMeters) {
      overridable.add(
          'GPS accuracy too low (±${accuracyMeters.toStringAsFixed(0)}m) — move to open sky and retry.');
    }
    if (isMocked) {
      if (policy.blockOnMockLocation) {
        integrity.add('Mock/fake location detected.');
      } else {
        warnings.add('Simulated location detected (allowed in this build).');
      }
    }
    if (vpnDetected) {
      if (policy.blockOnVpn) {
        integrity.add('Disable your VPN to check in.');
      } else {
        warnings.add(
            'VPN or proxy detected — location verification may be unreliable.');
      }
    }

    final blocked = [...overridable, ...integrity];
    return CheckInValidation(
      allowed: blocked.isEmpty,
      blockedReasons: blocked,
      warnings: warnings,
      overridableReasons: overridable,
      integrityReasons: integrity,
    );
  }

  /// Flags a consecutive sample pair as an "impossible travel" / teleport
  /// event if the implied speed exceeds [FraudPolicy.maxSpeedKmh].
  bool isImpossibleTravel(
      LocationSample previous, LocationSample current, FraudPolicy policy) {
    final seconds = current.timestamp.difference(previous.timestamp).inSeconds;
    if (seconds <= 0) return false;
    final meters = GeofenceService.distanceMeters(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final kmh = (meters / 1000) / (seconds / 3600);
    return kmh > policy.maxSpeedKmh;
  }

  /// Best-effort, dependency-free VPN heuristic: on mobile, scans active
  /// network interfaces for common VPN tunnel naming patterns (`tun`, `ppp`,
  /// `utun` on iOS). Not authoritative — swappable for a dedicated detection
  /// plugin later without changing any call site.
  ///
  /// **Always false on web**: browsers cannot enumerate network interfaces, so
  /// this control does not exist there. See `core/platform/environment/vpn_probe_web.dart`
  /// — it carries a `TODO(release-gate)` for exactly this weakening.
  Future<bool> detectVpnHeuristic() async {
    // TODO(release-gate): a demo build sends nothing off the device, and the
    // web probe is a third-party HTTP lookup.
    if (DataSourceMode.useMocks) return false;
    try {
      return await probeVpnInterfaces();
    } catch (_) {
      return false;
    }
  }
}
