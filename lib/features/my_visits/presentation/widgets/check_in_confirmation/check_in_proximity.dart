part of '../check_in_confirmation_dialog.dart';

class _SearchProgress extends StatelessWidget {
  const _SearchProgress({required this.startedAt});

  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final total = LocationTrackingCubit.fixSearchTimeout;
    final elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt!);
    final int seconds = elapsed.inSeconds.clamp(0, total.inSeconds).toInt();
    final progress = (elapsed.inMilliseconds / total.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final tip = _Copy.tips[(seconds ~/ 4) % _Copy.tips.length];
    final slow = seconds >= total.inSeconds * 0.55;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(14), vertical: context.rh(12)),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                slow ? _Copy.takingLonger : _Copy.searchingFor,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${seconds}s',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          // Tweened between the one-second ticks so the bar glides instead of
          // stepping.
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.linear,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: scheme.primary.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            ),
          ),
          SizedBox(height: context.rh(10)),
          _FadeSwap(
            swapKey: tip,
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: context.rr(14), color: colors.textSecondary),
                SizedBox(width: context.rw(6)),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Measured — distance, radius, proximity track, signal quality
// ═════════════════════════════════════════════════════════════════════════════

class _ProximityCard extends StatelessWidget {
  const _ProximityCard({required this.reading, required this.accent});

  final CheckInReading reading;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Whole metres, through intl: a rep does not need centimetres, and the
    // separator is locale-dependent once the figure passes a thousand.
    final format = NumberFormat.decimalPattern(context.languageCode)
      ..maximumFractionDigits = 0;
    String metres(double v) => 'my_visits.check_in_verification.meters'
        .trParams({'value': format.format(v)});

    final radius = reading.radiusMeters;
    final span = math.max(radius * 2, 1.0);
    final position = (reading.distanceMeters / span).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          context.rw(14), context.rh(12), context.rw(14), context.rh(12)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Metric(
                  label: 'my_visits.check_in_verification.distance_label'.tr,
                  // Counts to the new figure rather than jumping to it.
                  value: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: reading.distanceMeters),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      metres(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: context.rsp(20),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: context.rh(34),
                color: colors.border,
                margin: EdgeInsets.symmetric(horizontal: context.rw(12)),
              ),
              Expanded(
                child: _Metric(
                  label: 'my_visits.check_in_verification.radius_label'.tr,
                  value: Text(
                    metres(radius),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(15),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(14)),
          _ProximityTrack(position: position, accent: accent),
          SizedBox(height: context.rh(4)),
          Row(
            children: [
              Text(_Copy.outlet, style: _trackLabel(context)),
              const Spacer(),
              Text(metres(radius), style: _trackLabel(context)),
              const Spacer(),
              Text('${metres(span)}+', style: _trackLabel(context)),
            ],
          ),
          SizedBox(height: context.rh(10)),
          _SignalRow(
            accuracyMeters: reading.accuracyMeters,
            maxAccuracyMeters: reading.maxAccuracyMeters,
          ),
        ],
      ),
    );
  }

  TextStyle _trackLabel(BuildContext context) => TextStyle(
        color: context.appColors.textSecondary,
        fontSize: context.rsp(9.5),
        fontWeight: FontWeight.w600,
      );
}

/// A bar from the outlet (left) to twice the radius (right), with the allowed
/// zone shaded and the rep's marker gliding to their distance.
class _ProximityTrack extends StatelessWidget {
  const _ProximityTrack({required this.position, required this.accent});

  /// 0 = on the pin, 0.5 = on the radius edge, 1 = twice the radius or more.
  final double position;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final marker = context.rr(16);

    return SizedBox(
      height: marker,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: width / 2,
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    colors.success.withValues(alpha: 0.55),
                    colors.success.withValues(alpha: 0.25),
                  ]),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: position),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Positioned(
                  left: (width - marker) * v,
                  child: child!,
                ),
                child: Container(
                  width: marker,
                  height: marker,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
