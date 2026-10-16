part of '../check_in_confirmation_dialog.dart';

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.accuracyMeters,
    required this.maxAccuracyMeters,
  });

  final double accuracyMeters;
  final double maxAccuracyMeters;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final level = signalLevelFor(accuracyMeters, maxAccuracyMeters);
    final (label, color) = switch (level) {
      >= 3 => (_Copy.strong, colors.success),
      2 => (_Copy.fair, colors.success),
      _ => (_Copy.weak, colors.warning),
    };

    return Row(
      children: [
        SignalBars(level: level, color: color),
        SizedBox(width: context.rw(8)),
        Text(
          '${_Copy.accuracy} ±${accuracyMeters.round()} m',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: context.rsp(11),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: context.rsp(10.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// 1–4 bars from a fix's accuracy radius, relative to the policy ceiling.
int signalLevelFor(double accuracyMeters, double maxAccuracyMeters) {
  if (accuracyMeters <= 0) return 4; // static/debug position
  if (accuracyMeters <= maxAccuracyMeters * 0.3) return 4;
  if (accuracyMeters <= maxAccuracyMeters * 0.6) return 3;
  if (accuracyMeters <= maxAccuracyMeters) return 2;
  return 1;
}

/// Four rising bars, filled to [level]. Heights and colours animate, so a fix
/// improving from Weak to Strong visibly climbs.
class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++) ...[
          AnimatedContainer(
            duration: Duration(milliseconds: 250 + i * 60),
            curve: Curves.easeOutCubic,
            width: 3.5,
            height: 4.0 + i * 3,
            decoration: BoxDecoration(
              color: i <= level ? color : colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (i < 4) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 2,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: context.rsp(10.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.rh(3)),
        value,
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Actions
// ═════════════════════════════════════════════════════════════════════════════
