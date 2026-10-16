part of '../stops_check_in_screen.dart';

/// The live location status above the proof photo.
///
/// Renders from the same [CheckInReading] as the dialog. Each phase has its
/// own pill, cross-faded on change; the searching pill carries a soft sweep so
/// it reads as *working*, and the states the rep can fix carry the button that
/// fixes them.
class _GeoStatusBanner extends StatelessWidget {
  const _GeoStatusBanner({
    required this.reading,
    required this.blockedReason,
    required this.warnings,
    required this.onAction,
  });

  final CheckInReading reading;
  final String? blockedReason;
  final List<String> warnings;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final phase = reading.phase;
    final radius = reading.radiusMeters.round();
    final distance =
        reading.verdict.isMeasurable ? reading.distanceMeters.round() : 0;

    final (
      Color color,
      IconData icon,
      String text,
      String subtitle,
      String? action
    ) = switch (phase) {
      CheckInGpsPhase.within => (
          colors.success,
          Icons.check_circle_rounded,
          // The key is a template — `{dist}` must be filled, or the rep sees
          // the placeholder itself ("GPS {dist} m away").
          'my_visits.flow.geo_matchedTemplate'
              .tr
              .replaceAll('{dist}', '$distance'),
          'my_visits.flow.transit_banner_ready'.tr,
          null,
        ),
      CheckInGpsPhase.outside => (
          colors.warning,
          Icons.wrong_location_rounded,
          'my_visits.flow.geo_not_matched'.tr.replaceAll('{dist}', '$distance'),
          'my_visits.flow.transit_disclaimer'
              .tr
              .replaceAll('{radius}', '$radius'),
          null,
        ),
      CheckInGpsPhase.weakSignal => (
          colors.warning,
          Icons.network_check_rounded,
          'my_visits.check_in_gps.weak_title'
              .trParams({'accuracy': '${reading.accuracyMeters.round()}'}),
          'my_visits.check_in_gps.weak_body'.tr,
          null,
        ),
      CheckInGpsPhase.searching => (
          scheme.primary,
          Icons.gps_not_fixed_rounded,
          'my_visits.check_in_gps.searching_title'.tr,
          'my_visits.check_in_gps.searching_body'.tr,
          null,
        ),
      CheckInGpsPhase.servicesDisabled => (
          colors.warning,
          Icons.location_disabled_rounded,
          'my_visits.check_in_gps.services_title'.tr,
          'my_visits.check_in_gps.services_body'.tr,
          'my_visits.check_in_gps.services_action'.tr,
        ),
      CheckInGpsPhase.permissionDenied => (
          colors.warning,
          Icons.lock_outline_rounded,
          'my_visits.check_in_gps.permission_title'.tr,
          'my_visits.check_in_gps.permission_body'.tr,
          'my_visits.check_in_gps.permission_action'.tr,
        ),
      CheckInGpsPhase.permissionDeniedForever => (
          colors.warning,
          Icons.lock_outline_rounded,
          'my_visits.check_in_gps.blocked_title'.tr,
          'my_visits.check_in_gps.blocked_body'.tr,
          'my_visits.check_in_gps.blocked_action'.tr,
        ),
      CheckInGpsPhase.unavailable => (
          colors.warning,
          Icons.gps_off_rounded,
          'my_visits.check_in_gps.unavailable_title'.tr,
          'my_visits.check_in_gps.unavailable_body'.tr,
          'my_visits.check_in_gps.unavailable_action'.tr,
        ),
      CheckInGpsPhase.noOutlet => (
          scheme.primary,
          Icons.add_location_alt_rounded,
          'my_visits.check_in_verification.no_outlet_title'.tr,
          'my_visits.check_in_verification.no_outlet_body'.tr,
          null,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: _StatusPill(
            key: ValueKey(phase),
            color: color,
            icon: icon,
            text: text,
            subtitle: subtitle,
            shimmer: phase == CheckInGpsPhase.searching,
            trailing: phase.isMeasured
                ? SignalBars(
                    level: signalLevelFor(
                        reading.accuracyMeters, reading.maxAccuracyMeters),
                    color: color,
                  )
                : null,
            actionLabel: action,
            onAction: action == null ? null : onAction,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blockedReason != null) ...[
                SizedBox(height: context.rh(8)),
                _StatusPill(
                  color: scheme.error,
                  icon: Icons.block_rounded,
                  text: blockedReason!,
                ),
              ],
              for (final warning in warnings) ...[
                SizedBox(height: context.rh(8)),
                _StatusPill(
                  color: colors.warning,
                  icon: Icons.warning_amber_rounded,
                  text: warning,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatefulWidget {
  const _StatusPill({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.subtitle,
    this.shimmer = false,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  final Color color;
  final IconData icon;
  final String text;
  final String? subtitle;

  /// A slow light sweep across the pill — "working on it", without a spinner.
  final bool shimmer;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.shimmer) _sweep.repeat();
  }

  @override
  void didUpdateWidget(covariant _StatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shimmer && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (!widget.shimmer && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: context.rr(18), color: color),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.text,
                  style: TextStyle(
                    color: color,
                    fontSize: context.rsp(12.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  SizedBox(height: context.rh(2)),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: context.rsp(11),
                    ),
                  ),
                ]
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            SizedBox(width: context.rw(8)),
            widget.trailing!,
          ],
          if (widget.actionLabel != null) ...[
            SizedBox(width: context.rw(8)),
            TextButton(
              onPressed: widget.onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                backgroundColor: color.withValues(alpha: 0.12),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                widget.actionLabel!,
                style: TextStyle(
                  fontSize: context.rsp(11.5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!widget.shimmer) return pill;

    // The sweep is a moving gradient over the pill, repainted straight off the
    // controller — no rebuilds while it runs.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          pill,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_sweep.value);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.6 + 3.2 * t, 0),
                        end: Alignment(-0.6 + 3.2 * t, 0),
                        colors: [
                          color.withValues(alpha: 0),
                          color.withValues(alpha: 0.10),
                          color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
