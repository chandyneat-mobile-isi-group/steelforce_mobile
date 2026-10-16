import 'package:steelforce/features/my_visits/domain/services/check_in_location_verifier.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/location_tracking_state.dart';

/// Everything the check-in UI can be saying about location, in one place.
///
/// The header chip, the status banner and the verification dialog all render
/// from this one value. Before, each read a different source — the dialog a
/// verdict computed once when it opened, the banner the bloc's
/// `insideGeofence`, the header the bloc's `distanceMeters` (which reads `0 m`
/// before any fix) — so the screen could show "0 m • ~1 min" above a dialog
/// saying it had no idea where the rep was.
enum CheckInGpsPhase {
  /// Looking for a position; nothing usable yet.
  searching,

  /// Location Services are off.
  servicesDisabled,

  /// Permission refused — can be asked again.
  permissionDenied,

  /// Permission refused permanently — app settings only.
  permissionDeniedForever,

  /// The search finished with no fix at all.
  unavailable,

  /// The outlet has no recorded pin; there is no area to be inside of.
  noOutlet,

  /// Inside the check-in area, on a fix good enough to judge.
  within,

  /// Inside the area by distance, but the fix is too coarse to be sure.
  weakSignal,

  /// Measured, and outside the area.
  outside;

  /// Resolves the phase from the verifier's verdict and the tracker's status.
  ///
  /// Pure — no clock, no I/O — so it is trivially testable and every widget
  /// calling it with the same inputs agrees.
  static CheckInGpsPhase resolve({
    required CheckInLocationVerdict verdict,
    required GpsFixStatus fixStatus,
    required double accuracyMeters,
    required double maxAccuracyMeters,
  }) {
    if (!verdict.hasOutletLocation) return CheckInGpsPhase.noOutlet;

    if (verdict.hasDeviceFix) {
      if (!verdict.isWithinRadius) return CheckInGpsPhase.outside;
      return accuracyMeters > maxAccuracyMeters
          ? CheckInGpsPhase.weakSignal
          : CheckInGpsPhase.within;
    }

    return switch (fixStatus) {
      GpsFixStatus.servicesDisabled => CheckInGpsPhase.servicesDisabled,
      GpsFixStatus.permissionDenied => CheckInGpsPhase.permissionDenied,
      GpsFixStatus.permissionDeniedForever =>
        CheckInGpsPhase.permissionDeniedForever,
      GpsFixStatus.unavailable => CheckInGpsPhase.unavailable,
      // `acquired` with no *usable* fix means the one we had went stale and
      // a refresh is under way — that is a search, from the rep's side.
      GpsFixStatus.idle ||
      GpsFixStatus.searching ||
      GpsFixStatus.acquired =>
        CheckInGpsPhase.searching,
    };
  }

  /// A position is known and a distance can be shown.
  bool get isMeasured =>
      this == within || this == weakSignal || this == outside;

  /// Location itself is blocked by a device setting the rep can change.
  bool get isBlockedBySetting =>
      this == servicesDisabled ||
      this == permissionDenied ||
      this == permissionDeniedForever;
}

/// One moment's answer to "can this rep check in from here, and why".
///
/// Built by the check-in screen from the live [LocationTrackingState] and
/// handed to every widget that talks about location, so they cannot disagree.
class CheckInReading {
  const CheckInReading({
    required this.verdict,
    required this.phase,
    required this.accuracyMeters,
    required this.maxAccuracyMeters,
    this.searchStartedAt,
  });

  final CheckInLocationVerdict verdict;
  final CheckInGpsPhase phase;

  /// The fix's own reported accuracy radius. 0 when there is no fix.
  final double accuracyMeters;

  /// The policy ceiling above which a fix counts as [CheckInGpsPhase.weakSignal].
  final double maxAccuracyMeters;

  /// When the current search began, for progress display.
  final DateTime? searchStartedAt;

  double get distanceMeters => verdict.distanceMeters;
  double get radiusMeters => verdict.radiusMeters;
}
