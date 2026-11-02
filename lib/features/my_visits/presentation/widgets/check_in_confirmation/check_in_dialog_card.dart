part of '../check_in_confirmation_dialog.dart';

/// Copy for the check-in confirmation dialog. Getters, not constants, so
/// every string re-translates when the language changes.
abstract final class _Copy {
  static String get searchingBody =>
      'my_visits.check_in_dialog.searching_body'.tr;
  static String get servicesOffTitle =>
      'my_visits.check_in_dialog.services_off_title'.tr;
  static String get servicesOffBody =>
      'my_visits.check_in_dialog.services_off_body'.tr;
  static String get deniedTitle => 'my_visits.check_in_dialog.denied_title'.tr;
  static String get deniedBody => 'my_visits.check_in_dialog.denied_body'.tr;
  static String get deniedForeverBody =>
      'my_visits.check_in_dialog.denied_forever_body'.tr;
  static String get unavailableTitle =>
      'my_visits.check_in_dialog.unavailable_title'.tr;
  static String get unavailableBody =>
      'my_visits.check_in_dialog.unavailable_body'.tr;
  static String get weakTitle => 'my_visits.check_in_dialog.weak_title'.tr;
  static String get weakBody => 'my_visits.check_in_dialog.weak_body'.tr;
  static String get accuracy => 'my_visits.check_in_dialog.accuracy'.tr;
  static String get strong => 'my_visits.check_in_dialog.strong'.tr;
  static String get fair => 'my_visits.check_in_dialog.fair'.tr;
  static String get weak => 'my_visits.check_in_dialog.weak'.tr;
  static String get searchingFor =>
      'my_visits.check_in_dialog.searching_for'.tr;
  static String get takingLonger =>
      'my_visits.check_in_dialog.taking_longer'.tr;
  static String get tryAgain => 'common.try_again'.tr;
  static String get refresh => 'my_visits.check_in_dialog.refresh'.tr;
  static String get withoutGps => 'my_visits.check_in_dialog.without_gps'.tr;
  static String get turnOn => 'my_visits.check_in_dialog.turn_on'.tr;
  static String get allow => 'my_visits.check_in_dialog.allow'.tr;
  static String get openSettings =>
      'my_visits.check_in_dialog.open_settings'.tr;
  static String get locating => 'my_visits.check_in_gps.locating'.tr;
  static String get outlet => 'my_visits.check_in_dialog.outlet'.tr;
  static List<String> get tips => <String>[
        'my_visits.check_in_dialog.tip_window'.tr,
        'my_visits.check_in_dialog.tip_wifi'.tr,
        'my_visits.check_in_dialog.tip_still'.tr,
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
