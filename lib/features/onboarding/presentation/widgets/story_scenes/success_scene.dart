import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:steelforce/features/onboarding/presentation/widgets/story_scenes/scene_parts.dart';

class SuccessScene extends StatelessWidget {
  const SuccessScene({super.key, required this.t, required this.success});

  final double t;
  final Color success;

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      t: t,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sized to own the frame. At 124 this mark was a small tick adrift
            // in white — the weakest beat in the set, despite being the payoff
            // the whole order flow builds to. Confidence here is mostly scale.
            SizedBox(
              width: 210,
              height: 210,
              child: CustomPaint(painter: _CheckPainter(t: t, color: success)),
            ),
            const SizedBox(height: 26),
            Opacity(
              opacity: sceneUnit((t - 0.50) / 0.28),
              child: const SceneText('ORDER CREATED',
                  size: 15, color: sceneInk, weight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;

    // The ring closes first, then the tick draws inside it. Sequencing the two
    // is what makes this read as confirmation rather than as a stamp.
    final ring = Curves.easeOutCubic.transform(sceneUnit(t / 0.46));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    final tick = Curves.easeOutCubic.transform(sceneUnit((t - 0.40) / 0.34));
    if (tick <= 0) return;

    final p = Path()
      ..moveTo(c.dx - r * 0.42, c.dy + r * 0.04)
      ..lineTo(c.dx - r * 0.10, c.dy + r * 0.36)
      ..lineTo(c.dx + r * 0.45, c.dy - r * 0.30);
    final segments = p.computeMetrics().toList();
    final total = segments.fold<double>(0, (a, b) => a + b.length);
    final drawn = Path();
    var remaining = tick * total;
    for (final seg in segments) {
      if (remaining <= 0) break;
      drawn.addPath(
          seg.extractPath(0, math.min(remaining, seg.length)), Offset.zero);
      remaining -= seg.length;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
