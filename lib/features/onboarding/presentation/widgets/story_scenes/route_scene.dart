import 'package:flutter/material.dart';
import 'package:steelforce/features/onboarding/presentation/widgets/story_scenes/scene_parts.dart';

/// A map view with the day's route drawing itself across it.
///
/// Presented as a rounded map *card* rather than a full-bleed illustration,
/// because that is what the rep actually sees in the app — the scene is meant
/// to be recognisable as the product, not as an abstract graphic.
class RouteScene extends StatelessWidget {
  const RouteScene({
    super.key,
    required this.t,
    required this.line,
    required this.marker,
  });

  final double t;
  final Color line;
  final Color marker;

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      t: t,
      child: Padding(
        // Tuned for the onboarding page that now hosts it: the illustration
        // gets a bounded box and the copy sits below, so the generous top and
        // bottom margins this carried as a full-screen splash scene are gone.
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFF7F9FB)),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _MapPainter(t: t, line: line, marker: marker),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // The route summary card, arriving once the line has been drawn —
            // the result of the navigation, not a label sitting over it.
            Opacity(
              opacity: sceneUnit((t - 0.62) / 0.24),
              child: SceneCard(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: line.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.route_rounded, size: 18, color: line),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SceneText('SELECTED ROUTE',
                              size: 9,
                              color: sceneMuted,
                              weight: FontWeight.w800,
                              align: TextAlign.left),
                          SizedBox(height: 3),
                          SceneText('Phnom Penh · 5 stops',
                              size: 14,
                              color: sceneInk,
                              weight: FontWeight.w800,
                              align: TextAlign.left),
                        ],
                      ),
                    ),
                    const SceneText('12.4 km',
                        size: 12, color: sceneMuted, weight: FontWeight.w700),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.t, required this.line, required this.marker});

  final double t;
  final Color line, marker;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // ── City blocks ─────────────────────────────────────────────────────────
    // Irregular rounded rects, not a grid: a perfect lattice reads as graph
    // paper. Fixed layout rather than random so the composition is stable.
    const blocks = <List<double>>[
      [0.04, 0.06, 0.30, 0.16],
      [0.40, 0.04, 0.26, 0.13],
      [0.72, 0.08, 0.24, 0.18],
      [0.06, 0.28, 0.22, 0.20],
      [0.34, 0.24, 0.30, 0.15],
      [0.70, 0.32, 0.26, 0.14],
      [0.04, 0.54, 0.26, 0.18],
      [0.36, 0.46, 0.24, 0.22],
      [0.66, 0.52, 0.30, 0.16],
      [0.10, 0.78, 0.30, 0.15],
      [0.48, 0.74, 0.22, 0.18],
      [0.76, 0.74, 0.20, 0.16],
    ];
    final blockPaint = Paint()..color = sceneBlockFill;
    for (final b in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b[0] * w, b[1] * h, b[2] * w, b[3] * h),
          const Radius.circular(5),
        ),
        blockPaint,
      );
    }

    // ── Roads ───────────────────────────────────────────────────────────────
    // White fill over a hairline casing, which is what makes a line read as a
    // road rather than as a stroke.
    final casing = Paint()
      ..color = sceneHairline
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final tarmac = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roads = <List<Offset>>[
      [Offset(0, h * 0.235), Offset(w, h * 0.215)],
      [Offset(0, h * 0.445), Offset(w, h * 0.465)],
      [Offset(0, h * 0.715), Offset(w, h * 0.700)],
      [Offset(w * 0.325, 0), Offset(w * 0.345, h)],
      [Offset(w * 0.665, 0), Offset(w * 0.645, h)],
    ];
    for (final p in [casing, tarmac]) {
      for (final r in roads) {
        canvas.drawLine(r.first, r.last, p);
      }
    }

    // ── The route ───────────────────────────────────────────────────────────
    // Follows the road network rather than cutting across blocks — that is the
    // difference between "a route" and "a line on a picture of a map".
    final start = Offset(w * 0.16, h * 0.86);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(w * 0.16, h * 0.715)
      ..lineTo(w * 0.345, h * 0.715)
      ..lineTo(w * 0.345, h * 0.455)
      ..lineTo(w * 0.645, h * 0.455)
      ..lineTo(w * 0.645, h * 0.225)
      ..lineTo(w * 0.84, h * 0.225);

    final metric = path.computeMetrics().first;

    // Faint full route first: the rep sees the whole plan, then watches it
    // being travelled. Drawing only the travelled part hides where they are
    // going, which is the one thing a route view exists to show.
    canvas.drawPath(
      path,
      Paint()
        ..color = line.withValues(alpha: 0.16)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Progress along the route. Held back until the map has settled, and eased
    // so it accelerates away from the depot and slows into the depot.
    final travelled =
        Curves.easeInOutCubic.transform(sceneUnit((t - 0.18) / 0.52));
    if (travelled > 0) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * travelled),
        Paint()
          ..color = line
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Stop markers ────────────────────────────────────────────────────────
    // Intermediate stops, revealed as the route reaches each one.
    const stops = [0.28, 0.52, 0.74];
    for (final s in stops) {
      if (travelled < s) continue;
      final at = metric.getTangentForOffset(metric.length * s)!.position;
      canvas.drawCircle(at, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = line,
      );
    }

    // Origin: depot.
    canvas.drawCircle(start, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      start,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = sceneMuted,
    );

    // The rep's position rides the leading edge of the travelled path, so it
    // is always on the line rather than racing ahead of it.
    if (travelled > 0 && travelled < 1) {
      final pos =
          metric.getTangentForOffset(metric.length * travelled)!.position;
      canvas.drawCircle(
          pos, 15, Paint()..color = marker.withValues(alpha: 0.18));
      canvas.drawCircle(pos, 7.5, Paint()..color = Colors.white);
      canvas.drawCircle(pos, 5.5, Paint()..color = marker);
    }

    // Destination pin drops once the route arrives.
    final arrived =
        Curves.easeOutBack.transform(sceneUnit((travelled - 0.88) / 0.12));
    if (arrived > 0) {
      final end = metric.getTangentForOffset(metric.length)!.position;
      canvas.drawCircle(
          end, 16 * arrived, Paint()..color = marker.withValues(alpha: 0.16));
      canvas.drawCircle(end, 7 * arrived, Paint()..color = marker);
      canvas.drawCircle(end, 3 * arrived, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.t != t;
}
