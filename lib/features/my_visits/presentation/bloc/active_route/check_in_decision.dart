import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';

/// Whether a check-in at the current stop may go ahead, and what it carries.
///
/// Pure: the bloc does the I/O (VPN probe, fraud-flag writes, the save) and
/// this decides. `test/features/my_visits/active_route_bloc_flow_test.dart`
/// pins the rules through the bloc.
class CheckInDecision {
  const CheckInDecision({
    required this.allowed,
    required this.blockedReason,
    required this.overridable,
    required this.warnings,
    required this.flags,
    required this.storedReason,
  });

  /// False when the rules refuse the check-in.
  final bool allowed;

  /// The joined block reasons, when refused.
  final String? blockedReason;

  /// Whether the screen may offer "check in anyway" with a written reason.
  final bool overridable;

  /// Shown on the check-in, in order.
  final List<String> warnings;

  /// Fraud-trail entries to record — raised even when the check-in is refused.
  final List<({FraudFlagType type, String detail})> flags;

  /// The rep's reason, stored on the check-in row; null unless they overrode
  /// something or explained a check-in with no location evidence.
  final String? storedReason;
}

CheckInDecision decideCheckIn({
  required ActiveRouteReady current,
  required FraudDetectionService service,
  required FraudPolicy policy,
  required bool vpnDetected,
  required String? overrideReason,
}) {
  // Three different situations reach the geofence rule, and only one of them
  // is the rep's doing.
  //
  // - Inside / outside a known geofence with a known position → the real
  //   verdict, enforced.
  // - **No GPS fix yet** → nothing has been measured. Blocking here is what
  //   made check-in impossible: `_onStopSelected` writes
  //   `insideGeofence: false`, and until a fix arrives there is nothing to
  //   overwrite it with. A rep in a metal-roofed warehouse would wait
  //   forever for a verdict that says only "we did not look".
  // - **Depot has no coordinates** → there is no geofence to be outside
  //   of (`GeofenceService.evaluate` returns `locationKnown: false` for
  //   exactly this).
  //
  // The last two record the visit as *unverifiable* — a warning on the row,
  // which the server already knows how to read (api.md §8.2: evidence, not a
  // verdict; a check-in with no fix is stored as unverifiable). They do not
  // refuse the work.
  final unverifiable = !current.hasFix || !current.depotLocationKnown;
  final validation = service.validateCheckIn(
    insideGeofence: unverifiable ? true : current.insideGeofence,
    accuracyMeters: current.accuracyMeters,
    isMocked: current.isMocked,
    vpnDetected: vpnDetected,
    policy: policy,
  );

  final warnings = <String>[
    ...validation.warnings,
    if (!current.hasFix)
      'No GPS fix yet — this check-in is recorded as unverified.',
    if (!current.depotLocationKnown)
      'This depot has no recorded location — the geofence could not be checked.',
  ];

  final flags = <({FraudFlagType type, String detail})>[
    for (final warning in validation.warnings)
      (
        type: current.isMocked
            ? FraudFlagType.mockLocation
            : FraudFlagType.vpnDetected,
        detail: warning,
      ),
  ];

  // A written reason carries the check-in past the location rules — and only
  // those. `canOverrideWithReason` is false the moment an integrity rule is
  // among the blocks, so a mocked position cannot be typed past.
  final reason = overrideReason?.trim() ?? '';
  final overrideOffered =
      policy.allowReasonedCheckInOverride && validation.canOverrideWithReason;
  final overrideAccepted =
      overrideOffered && reason.length >= policy.minOverrideReasonLength;

  if (!validation.allowed && !overrideAccepted) {
    return CheckInDecision(
      allowed: false,
      blockedReason: validation.blockedReasons.join(' '),
      // Tells the screen whether to offer "check in anyway" or just report
      // the block. Without it the UI would have to re-derive the rule split
      // by matching on message text.
      overridable: overrideOffered,
      warnings: warnings,
      flags: flags,
      storedReason: null,
    );
  }

  // A reason the rep gave that the location rules did not strictly need.
  //
  // The main case: no fix at all (or a shop with no pin), which was already
  // allowed through as *unverified* — and the check-in dialog's "Check in
  // without GPS" path always asks why. Keep that reason on the row.
  // Otherwise the check-in with the least location evidence would be the
  // only kind whose explanation is thrown away.
  //
  // Also covers a rep whose screen had no *fresh* fix while this bloc still
  // held an older one: the rep answered a question, so the answer is kept.
  final extraReasonGiven =
      !overrideAccepted && reason.length >= policy.minOverrideReasonLength;
  if (extraReasonGiven) {
    final String situation;
    if (!current.hasFix) {
      situation = 'No GPS fix.';
    } else if (!current.depotLocationKnown) {
      situation = 'Depot has no recorded location.';
    } else {
      situation = 'No fresh GPS fix on screen.';
    }
    flags.add((
      type: FraudFlagType.reasonedOverride,
      detail: '$situation Reason: $reason',
    ));
    warnings.add('Checked in without location verification. Reason: $reason');
  }

  if (overrideAccepted) {
    // Recorded in the fraud trail, not just in the note. The note travels
    // with the visit and is what a supervisor reads; the flag is what makes
    // override *frequency* answerable without parsing free text.
    flags.add((
      type: FraudFlagType.reasonedOverride,
      detail: '${validation.overridableReasons.join(' ')} Reason: $reason',
    ));
    warnings.add('Checked in outside the geofence. Reason: $reason');
  }

  return CheckInDecision(
    allowed: true,
    blockedReason: null,
    overridable: false,
    warnings: warnings,
    flags: flags,
    // Travels on the check-in row, so the reason and the verdict it explains
    // are one record. Null unless the rep actually overrode something —
    // `overrideAccepted` is false both for an ordinary check-in and for a
    // reason too short to have been meant.
    storedReason: (overrideAccepted || extraReasonGiven) ? reason : null,
  );
}
