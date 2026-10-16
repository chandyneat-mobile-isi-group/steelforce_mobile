import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One mote of steel dust.
///
/// Positions are stored in **unit space** (0–1 on both axes) so the field is
/// resolution-independent: the same field fills a 375×667 SE and a 430×932 Pro
/// Max without per-device tuning, which is what keeps the composition honest on
/// the 9:16 target the brief specifies.
@immutable
class _Mote {
  const _Mote({
    required this.origin,
    required this.drift,
    required this.radius,
    required this.phase,
    required this.bright,
  });

  final Offset origin;
  final Offset drift;
  final double radius;
  final double phase;

  /// A minority of motes are "hot" — they carry the cyan highlight instead of
  /// the muted steel. Roughly one in five, because a field where everything
  /// glows reads as noise rather than as metal catching the light.
  final bool bright;
}

/// The particle layer that runs underneath every scene of the splash story.
///
/// It exists to solve the brief's hardest requirement — that the scenes feel
/// like *one* continuous movement rather than seven cuts. The scenes above it
/// cross-fade; this field never does. It is the one element on screen for the
/// whole eight seconds, so the eye reads continuity through it even as the
/// content changes behind.
///
/// In the final beat the motes stop wandering and converge on the logo's
/// centre, which is what makes the logo look *assembled from* the story rather
/// than merely faded in after it.
class SteelParticleField extends StatelessWidget {
  const SteelParticleField({
    super.key,
    required this.progress,
    required this.steel,
    required this.highlight,
    this.count = 42,
    this.convergeFrom = 0.74,
  });

  /// Whole-story progress, 0–1. Not a per-scene value: the field spans scenes.
  final double progress;
  final Color steel;
  final Color highlight;

  /// Deliberately modest. This paints on every frame, and past roughly fifty
  /// the field stops reading as dust and starts costing frames on the low-end
  /// Androids a field sales team actually carries.
  final int count;

  /// Progress after which the motes stop wandering and gather on the centre.
  ///
  /// A parameter rather than a constant read from the splash's timeline: this
  /// widget lives in `shared/` and is used by two features now, so it must not
  /// depend on either one's schedule. The caller owns the timing.
  final double convergeFrom;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SteelParticlePainter(
          progress: progress,
          steel: steel,
          highlight: highlight,
          convergeFrom: convergeFrom,
          motes: _fieldOf(count),
        ),
      ),
    );
  }
}

/// Built once per [count] and cached.
///
/// A fresh `Random` on every build would re-scatter the field each frame and
/// turn drifting dust into television static — and because `build` runs ~60
/// times a second here, that bug would be invisible in code review and obvious
/// on device. The fixed seed also makes the composition reproducible, so a
/// golden test of this screen is stable.
final Map<int, List<_Mote>> _fieldCache = {};

List<_Mote> _fieldOf(int count) => _fieldCache.putIfAbsent(count, () {
      final rng = math.Random(0x5EE1);
      return List.generate(count, (_) {
        return _Mote(
          origin: Offset(rng.nextDouble(), rng.nextDouble()),
          // Drift is small: metal dust settling, not snow falling.
          drift: Offset(
            (rng.nextDouble() - 0.5) * 0.16,
            (rng.nextDouble() - 0.5) * 0.16,
          ),
          radius: 0.8 + rng.nextDouble() * 2.2,
          phase: rng.nextDouble() * math.pi * 2,
          bright: rng.nextInt(5) == 0,
        );
      });
    });

class _SteelParticlePainter extends CustomPainter {
  _SteelParticlePainter({
    required this.progress,
    required this.steel,
    required this.highlight,
    required this.convergeFrom,
    required this.motes,
  });

  final double progress;
  final Color steel;
  final Color highlight;
  final double convergeFrom;
  final List<_Mote> motes;

  @override
  void paint(Canvas canvas, Size size) {
    // Fade the field in over the first beat and out under the logo hold, so it
    // never competes with the mark it just formed.
    final entry = Curves.easeOut.transform(_unit(progress / 0.12));
    final exit = 1 - Curves.easeIn.transform(_unit((progress - 0.86) / 0.14));
    final fieldOpacity = entry * exit;
    if (fieldOpacity <= 0.01) return;

    // Where the motes gather in the final beat: the logo's optical centre,
    // which sits slightly above true centre because the wordmark hangs below.
    final focus = Offset(size.width * 0.5, size.height * 0.45);
    final converge = Curves.easeInOutCubic
        .transform(_unit((progress - convergeFrom) / 0.22));

    final dust = Paint()..style = PaintingStyle.fill;
    final glow = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

    for (final m in motes) {
      // Wander: a slow sine on each axis, offset per mote so the field never
      // pulses in unison.
      final t = progress * math.pi * 2;
      final wander = Offset(
        m.origin.dx + m.drift.dx * math.sin(t * 0.6 + m.phase),
        m.origin.dy + m.drift.dy * math.cos(t * 0.5 + m.phase),
      );
      final scattered = Offset(wander.dx * size.width, wander.dy * size.height);

      // Converge toward the focus point. Lerp rather than physics: it lands
      // exactly on the beat the logo needs it to, every time, on every device.
      final at = Offset.lerp(scattered, focus, converge)!;

      final base = m.bright ? highlight : steel;
      // Motes strengthen as they gather — the material "collecting" into the
      // mark. Alphas are deliberately low: these sit on white, where a value
      // that reads as delicate dust on navy reads as dirt on paper.
      final alpha = fieldOpacity * (0.16 + 0.34 * converge);
      dust.color = base.withValues(alpha: alpha.clamp(0.0, 1.0));

      if (m.bright) {
        // Halo only, and faint: a bloom that works against a dark backdrop
        // turns into a grey smudge on white.
        glow.color = base.withValues(alpha: (alpha * 0.35).clamp(0.0, 1.0));
        canvas.drawCircle(at, m.radius * 2.0, glow);
      }
      // Shrink on arrival so the field dissolves into the logo instead of
      // piling up as a visible clump of dots on top of it.
      canvas.drawCircle(at, m.radius * (1 - 0.55 * converge), dust);
    }
  }

  @override
  bool shouldRepaint(_SteelParticlePainter old) =>
      old.progress != progress ||
      old.steel != steel ||
      old.highlight != highlight ||
      old.convergeFrom != convergeFrom;
}

double _unit(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
