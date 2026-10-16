import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:steelforce/features/onboarding/presentation/widgets/story_scenes/scene_parts.dart';

/// The rep has arrived: the geofence confirms the location, and the visit
/// starts. Picks up where the route left off — the same blue marker, now
/// stationary and being verified.
class VisitScene extends StatelessWidget {
  const VisitScene({
    super.key,
    required this.t,
    required this.accent,
    required this.success,
  });

  final double t;
  final Color accent, success;

  @override
  Widget build(BuildContext context) {
    // The button presses itself near the end of the beat — the moment the
    // story hands over to the order flow.
    final press = sceneUnit((t - 0.74) / 0.16);
    final pressed = 1 - 0.055 * math.sin(press * math.pi);

    return SceneShell(
      t: t,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _GeofencePainter(t: t, accent: accent),
            ),
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: SceneCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SceneText('DEPOT VISIT',
                      size: 9, color: sceneMuted, weight: FontWeight.w800),
                  const SizedBox(height: 7),
                  const SceneText('Sok Dara Hardware',
                      size: 16, color: sceneInk, weight: FontWeight.w800),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 13, color: success),
                      const SizedBox(width: 5),
                      SceneText('Location verified',
                          size: 11, color: success, weight: FontWeight.w700),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Transform.scale(
            scale: pressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const SceneText('START VISIT',
                  size: 12, color: Colors.white, weight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeofencePainter extends CustomPainter {
  _GeofencePainter({required this.t, required this.accent});
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);

    // Three rings staggered in time — a check-in confirming, not a radar sweep.
    for (var i = 0; i < 3; i++) {
      final ring = sceneUnit((t - 0.18 - i * 0.15) / 0.55);
      if (ring <= 0) continue;
      final eased = Curves.easeOutCubic.transform(ring);
      canvas.drawCircle(
        centre,
        30 + eased * 58,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = accent.withValues(alpha: 0.34 * (1 - eased)),
      );
    }

    final pin = Curves.easeOutBack.transform(sceneUnit(t / 0.28));
    canvas.drawCircle(
        centre, 26 * pin, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.drawCircle(centre, 11 * pin, Paint()..color = Colors.white);
    canvas.drawCircle(centre, 8 * pin, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_GeofencePainter old) => old.t != t;
}
