part of '../check_in_confirmation_dialog.dart';

/// TODO(i18n): move to en/km. Literals on purpose, same as
/// `RemoteCheckInSheet`: a missing `.tr` key renders the key itself on a rep's
/// screen, which is worse than untranslated English. Strings that already had
/// keys still use them.
abstract final class _Copy {
  static const searchingBody =
      'Getting your position. This usually takes a few seconds.';
  static const servicesOffTitle = 'Location is off';
  static const servicesOffBody =
      'Turn on Location to verify your check-in. We will pick it up '
      'automatically when you come back.';
  static const deniedTitle = 'Location permission needed';
  static const deniedBody =
      'Allow location access so your check-in can be verified.';
  static const deniedForeverBody =
      'Location access is blocked for this app. Enable it in Settings → '
      'Permissions → Location.';
  static const unavailableTitle = 'No GPS signal here';
  static const unavailableBody =
      'We could not get a position after a full search. You can try again, '
      'or check in without GPS — you will be asked for a short reason and '
      'the visit is marked unverified.';
  static const weakTitle = 'Weak GPS signal';
  static const weakBody =
      'You look close enough, but the signal is too coarse to be sure. It '
      'is still improving — wait a moment, or continue with a reason.';
  static const accuracy = 'Accuracy';
  static const strong = 'Strong';
  static const fair = 'Fair';
  static const weak = 'Weak';
  static const searchingFor = 'Searching';
  static const takingLonger = 'Taking longer than usual…';
  static const tryAgain = 'Try again';
  static const refresh = 'Refresh';
  static const withoutGps = 'Check in without GPS';
  static const turnOn = 'Turn on location';
  static const allow = 'Allow location';
  static const openSettings = 'Open settings';
  static const locating = 'Locating…';
  static const outlet = 'Outlet';
  static const tips = <String>[
    'Tip: step near a window or doorway.',
    'Tip: keep Wi-Fi switched on — it speeds up location, even offline.',
    'Tip: hold the phone still for a moment.',
  ];
}

// ═════════════════════════════════════════════════════════════════════════════
// Card
// ═════════════════════════════════════════════════════════════════════════════

class _DialogCard extends StatelessWidget {
  const _DialogCard({
    required this.outletName,
    required this.reading,
    required this.onCancel,
    required this.onConfirm,
    required this.onWithReason,
    required this.onWithoutGps,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String outletName;
  final CheckInReading reading;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onWithReason;
  final VoidCallback onWithoutGps;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  static const _switchDuration = Duration(milliseconds: 320);

  Color _accent(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return switch (reading.phase) {
      CheckInGpsPhase.within || CheckInGpsPhase.noOutlet => colors.success,
      CheckInGpsPhase.searching => scheme.primary,
      // Amber, not red. The rep has done nothing wrong — they are standing
      // somewhere the rule does not cover, and red reads as a fault.
      _ => colors.warning,
    };
  }

  (String title, String body) _texts() => switch (reading.phase) {
        CheckInGpsPhase.searching => (
            'my_visits.check_in_verification.no_fix_title'.tr,
            _Copy.searchingBody,
          ),
        CheckInGpsPhase.servicesDisabled => (
            _Copy.servicesOffTitle,
            _Copy.servicesOffBody,
          ),
        CheckInGpsPhase.permissionDenied => (
            _Copy.deniedTitle,
            _Copy.deniedBody,
          ),
        CheckInGpsPhase.permissionDeniedForever => (
            _Copy.deniedTitle,
            _Copy.deniedForeverBody,
          ),
        CheckInGpsPhase.unavailable => (
            _Copy.unavailableTitle,
            _Copy.unavailableBody,
          ),
        CheckInGpsPhase.noOutlet => (
            'my_visits.check_in_verification.no_outlet_title'.tr,
            'my_visits.check_in_verification.no_outlet_body'.tr,
          ),
        CheckInGpsPhase.within => (
            'my_visits.check_in_verification.within_title'.tr,
            'my_visits.check_in_verification.within_body'.tr,
          ),
        CheckInGpsPhase.weakSignal => (_Copy.weakTitle, _Copy.weakBody),
        CheckInGpsPhase.outside => (
            'my_visits.check_in_verification.outside_title'.tr,
            'my_visits.check_in_verification.outside_body'.tr,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = _accent(context);
    final (title, body) = _texts();

    // The Dialog itself is transparent; the card is the Container, so the
    // accent-tinted shadow sits *behind* it rather than over its face.
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: context.rw(24)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(context.rr(24)),
          // Soft, accent-tinted shadow instead of Material elevation grey.
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              context.rw(20), context.rh(20), context.rw(20), context.rh(14)),
          child: AnimatedSize(
            duration: _switchDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LocatorBeacon(phase: reading.phase, accent: accent),
                SizedBox(height: context.rh(8)),
                Text(
                  'my_visits.check_in_verification.title'.tr.toUpperCase(),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(10.5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: context.rh(8)),
                _FadeSwap(
                  swapKey: title,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(18),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                SizedBox(height: context.rh(4)),
                Text(
                  outletName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(12.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: context.rh(14)),
                _FadeSwap(
                  swapKey: _contentKind(reading.phase),
                  child: _content(context, accent),
                ),
                SizedBox(height: context.rh(12)),
                _FadeSwap(
                  swapKey: body,
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12.5),
                      height: 1.45,
                    ),
                  ),
                ),
                SizedBox(height: context.rh(18)),
                _FadeSwap(
                  swapKey: reading.phase,
                  child: _Actions(
                    phase: reading.phase,
                    accent: accent,
                    onCancel: onCancel,
                    onConfirm: onConfirm,
                    onWithReason: onWithReason,
                    onWithoutGps: onWithoutGps,
                    onRetry: onRetry,
                    onOpenSettings: onOpenSettings,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _contentKind(CheckInGpsPhase phase) => switch (phase) {
        CheckInGpsPhase.searching => 'searching',
        CheckInGpsPhase.within ||
        CheckInGpsPhase.weakSignal ||
        CheckInGpsPhase.outside =>
          'measured',
        _ => 'none',
      };

  Widget _content(BuildContext context, Color accent) =>
      switch (reading.phase) {
        CheckInGpsPhase.searching =>
          _SearchProgress(startedAt: reading.searchStartedAt),
        CheckInGpsPhase.within ||
        CheckInGpsPhase.weakSignal ||
        CheckInGpsPhase.outside =>
          _ProximityCard(reading: reading, accent: accent),
        CheckInGpsPhase.servicesDisabled ||
        CheckInGpsPhase.permissionDenied ||
        CheckInGpsPhase.permissionDeniedForever ||
        CheckInGpsPhase.unavailable ||
        CheckInGpsPhase.noOutlet =>
          const SizedBox(width: double.infinity),
      };
}

/// Cross-fades and lifts content when [swapKey] changes. The one transition
/// used everywhere in the dialog, so every change moves the same way.
class _FadeSwap extends StatelessWidget {
  const _FadeSwap({required this.swapKey, required this.child});

  final Object swapKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<Object>(swapKey), child: child),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Beacon — radar rings while searching, a settled badge once measured
// ═════════════════════════════════════════════════════════════════════════════
