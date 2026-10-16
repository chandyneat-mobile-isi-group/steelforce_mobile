part of '../stops_check_in_screen.dart';

/// Fades and lifts [child] in over its own slice ([begin]–[end]) of the
/// shared entrance timeline. Several of these on one controller give a smooth
/// top-to-bottom cascade for the price of a single ticker.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
    this.offset = 0.08,
  });

  final AnimationController controller;
  final double begin;
  final double end;

  /// Starting vertical offset, as a fraction of the child's own height.
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, offset), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}

class _UnifiedDepotHeader extends StatelessWidget {
  const _UnifiedDepotHeader({
    required this.stop,
    required this.reading,
  });

  final RouteStop stop;
  final CheckInReading reading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      color: colors.card,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.localized(stop.depot.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(17),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: context.rh(3)),
                Text(
                  stop.depot.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(12.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.rw(12)),
          _DistanceChip(reading: reading),
        ],
      ),
    );
  }
}

/// The header's distance pill.
///
/// It used to read the bloc's `distanceMeters`, which defaults to **0** — so
/// before any fix it proudly said "0 m • ~1 min" while the dialog below said it
/// had no idea where the rep was. Now it says "Locating…" until something is
/// measured, then glides to the real figure.
class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.reading});

  final CheckInReading reading;

  static int _etaMinutes(double meters) =>
      max(1, ((meters / 1000) / 25 * 60).round());

  static String _distanceLabel(double meters) {
    final km = meters / 1000;
    return km < 0.1 ? '${meters.round()} m' : '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final phase = reading.phase;

    final Color tone = switch (phase) {
      CheckInGpsPhase.within => colors.success,
      CheckInGpsPhase.searching || CheckInGpsPhase.noOutlet => scheme.primary,
      _ => colors.warning,
    };

    final Widget content;
    if (phase.isMeasured) {
      final distance = reading.distanceMeters;
      content = Row(
        key: const ValueKey('measured'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.navigation_rounded, color: tone, size: context.rr(14)),
          SizedBox(width: context.rw(5)),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: distance),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              // `trParams`, not `.tr` with the number glued on outside —
              // `minutes_shortTemplate` is `'{minutes} min'` (FS-LOC-3).
              '${_distanceLabel(v)} • ~'
              '${'my_visits.flow.minutes_shortTemplate'.trParams({
                    'minutes': _etaMinutes(v),
                  })}',
              style: TextStyle(
                color: tone,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    } else {
      final (IconData icon, String label) = switch (phase) {
        CheckInGpsPhase.servicesDisabled => (
            Icons.location_disabled_rounded,
            'my_visits.check_in_gps.services_off'.tr,
          ),
        CheckInGpsPhase.permissionDenied ||
        CheckInGpsPhase.permissionDeniedForever =>
          (
            Icons.lock_outline_rounded,
            'my_visits.check_in_gps.no_permission'.tr
          ),
        CheckInGpsPhase.unavailable => (
            Icons.gps_off_rounded,
            'my_visits.check_in_gps.no_gps'.tr,
          ),
        CheckInGpsPhase.noOutlet => (
            Icons.add_location_alt_rounded,
            'my_visits.check_in_gps.no_pin'.tr,
          ),
        _ => (
            Icons.gps_not_fixed_rounded,
            'my_visits.check_in_gps.locating'.tr
          ),
      };
      content = Row(
        key: ValueKey(label),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (phase == CheckInGpsPhase.searching)
            SizedBox(
              width: context.rr(12),
              height: context.rr(12),
              child: CircularProgressIndicator(strokeWidth: 1.8, color: tone),
            )
          else
            Icon(icon, color: tone, size: context.rr(14)),
          SizedBox(width: context.rw(6)),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: context.rsp(11.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(a),
              child: child,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
