import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/location_tracking_state.dart';
import 'package:steelforce/features/my_visits/presentation/models/check_in_gps_phase.dart';

part 'check_in_confirmation/check_in_dialog_card.dart';
part 'check_in_confirmation/check_in_locator_beacon.dart';
part 'check_in_confirmation/check_in_proximity.dart';
part 'check_in_confirmation/check_in_signal.dart';
part 'check_in_confirmation/check_in_dialog_actions.dart';

/// What the rep chose in [CheckInConfirmationDialog].
enum CheckInConfirmation {
  /// Inside the area (or the outlet has no pin) — proceed with the check-in.
  confirmed,

  /// Outside the area, or inside it on a fix too coarse to judge. The caller
  /// must collect a written reason before dispatching.
  withReason,

  /// No position could be found at all after a full search. The caller must
  /// collect a written reason; the check-in is recorded as **unverified**.
  withoutGps,
}

/// Live location verification, shown before a check-in is dispatched.
///
/// ## What changed, and why it fixes "cannot check in"
///
/// This dialog used to receive a verdict computed **once**, at the moment the
/// rep tapped the button. If there was no fix at that instant it rendered
/// "Locating You — Waiting for a GPS fix" with a single **Cancel** button, and
/// nothing on it could ever change: no fix arriving later reached it, no
/// retry existed, and the only way forward was to cancel and hope. On a
/// handset indoors that was a permanent dead end — while the bloc underneath
/// would actually have accepted the check-in as unverified.
///
/// Now it is **live**. It listens to [LocationTrackingCubit] and re-verifies on
/// every fix, so it moves from *searching* to *within* on its own the moment a
/// position lands. It asks for a fresh fix when it opens. And every state has
/// a way forward:
///
/// | phase               | primary action                               |
/// |---------------------|----------------------------------------------|
/// | searching           | (waits, with progress)                       |
/// | within / no pin     | Confirm Check-In                             |
/// | weak signal/outside | Continue with reason                         |
/// | Location off        | Turn on location                             |
/// | permission refused  | Allow / Open settings                        |
/// | no fix after 15 s   | Check in without GPS (reason required)       |
///
/// None of these fabricate a position. "Without GPS" is recorded unverified
/// with the rep's reason on the row, exactly the evidence api.md §8.2 expects.
///
/// Returns null when the rep cancelled.
class CheckInConfirmationDialog extends StatefulWidget {
  const CheckInConfirmationDialog({
    super.key,
    required this.outletName,
    required this.locationCubit,
    required this.read,
  });

  final String outletName;
  final LocationTrackingCubit locationCubit;

  /// Turns a tracker state into the verdict for this stop. Supplied by the
  /// screen so the dialog and the screen use the same outlet and radius.
  final CheckInReading Function(LocationTrackingState state) read;

  static Future<CheckInConfirmation?> show(
    BuildContext context, {
    required String outletName,
    required LocationTrackingCubit locationCubit,
    required CheckInReading Function(LocationTrackingState state) read,
  }) =>
      showGeneralDialog<CheckInConfirmation>(
        context: context,
        // The rep must answer it: this decides whether a durable record is
        // written, and a dialog dismissed by a stray tap on the scrim leaves
        // them unsure whether they checked in.
        barrierDismissible: false,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 340),
        pageBuilder: (_, __, ___) => CheckInConfirmationDialog(
          outletName: outletName,
          locationCubit: locationCubit,
          read: read,
        ),
        // Scale-and-fade with a gentle overshoot on the way in, a quick plain
        // fade on the way out. No backdrop blur: animating a blur every frame
        // is what makes dialogs stutter on mid-range Android.
        transitionBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  State<CheckInConfirmationDialog> createState() =>
      _CheckInConfirmationDialogState();
}

class _CheckInConfirmationDialogState extends State<CheckInConfirmationDialog> {
  Timer? _ticker;
  CheckInGpsPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    // Ask for a position *now*. A stationary handset's last stream sample may
    // be minutes old; the rep is agreeing to the distance on this dialog, so it
    // should be about where they stand at this moment.
    unawaited(widget.locationCubit.refreshFix());
    // One tick a second, for the elapsed counter and rotating tips. Cheap: it
    // rebuilds one small dialog, and stops with it.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onPhase(CheckInGpsPhase phase) {
    final previous = _lastPhase;
    _lastPhase = phase;
    if (previous == null || previous == phase) return;
    // Felt, not just seen: a light tick when a fix lands, a firmer one for the
    // states that need the rep to do something.
    try {
      if (phase == CheckInGpsPhase.within) {
        HapticFeedback.lightImpact();
      } else if (phase.isBlockedBySetting ||
          phase == CheckInGpsPhase.unavailable) {
        HapticFeedback.mediumImpact();
      } else if (phase.isMeasured && !previous.isMeasured) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationTrackingCubit, LocationTrackingState>(
      bloc: widget.locationCubit,
      builder: (context, trackerState) {
        final reading = widget.read(trackerState);
        _onPhase(reading.phase);
        return _DialogCard(
          outletName: widget.outletName,
          reading: reading,
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () =>
              Navigator.of(context).pop(CheckInConfirmation.confirmed),
          onWithReason: () =>
              Navigator.of(context).pop(CheckInConfirmation.withReason),
          onWithoutGps: () =>
              Navigator.of(context).pop(CheckInConfirmation.withoutGps),
          onRetry: () => unawaited(widget.locationCubit.retryFix()),
          onOpenSettings: () =>
              unawaited(widget.locationCubit.openSettingsForStatus()),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Copy
// ═════════════════════════════════════════════════════════════════════════════
