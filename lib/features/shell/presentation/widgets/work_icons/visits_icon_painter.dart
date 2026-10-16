import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/work_icon_drawing.dart';

/// A route tracing itself across a map tile to an outlet, a pin dropping on
/// it, then the visit checked off.
///
/// No captions: the earlier "Depot"/"Outlet" labels were 7pt English text
/// inside a drawing, unreadable at card size and untranslatable. The start
/// ring, the route and the shopfront say the same thing in any language.
class VisitsIconPainter extends CustomPainter {
  VisitsIconPainter({required this.t, required this.accent});

  final double t;
  final Color accent;

  static const _start = Offset(20, 80);
  static const _end = Offset(50, 66);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final o = loopCycleOpacity(t);
    if (o <= 0.01) return;
    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: o));

    _mapTile(canvas, s);
    _shop(canvas, s, loopPhase(t, 0.04, 0.20, Curves.easeOutBack));

    // ── The route ─────────────────────────────────────────────────────────
    final route = Path()
      ..moveTo(_start.dx * s, _start.dy * s)
      ..cubicTo(18 * s, 64 * s, 28 * s, 72 * s, 34 * s, 62 * s)
      ..cubicTo(38 * s, 55 * s, 46 * s, 56 * s, _end.dx * s, _end.dy * s);
    final metric = route.computeMetrics().first;

    // The whole way, dashed and faint: where the rep is going.
    const dash = 4.0, gap = 4.0;
    for (var d = 0.0; d < metric.length; d += (dash + gap) * s) {
      canvas.drawPath(
        metric.extractPath(d, math.min(d + dash * s, metric.length)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * s
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.28),
      );
    }

    // The way already travelled: solid, Ironclad into the accent, lit.
    final travelled = loopPhase(t, 0.16, 0.50, Curves.easeInOutCubic);
    if (travelled > 0) {
      final done = metric.extractPath(0, metric.length * travelled);
      canvas.drawPath(
        done,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 * s
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
      );
      canvas.drawPath(
        done,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5 * s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(colors: [iconInk, accent]).createShader(
            Rect.fromPoints(_start * s, _end * s),
          ),
      );

      // The travelling head, until the pin takes over.
      if (travelled < 1) {
        final head =
            metric.getTangentForOffset(metric.length * travelled)!.position;
        canvas.drawCircle(
          head,
          6 * s,
          Paint()
            ..color = accent.withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s),
        );
        canvas.drawCircle(head, 3.4 * s, Paint()..color = iconPaper);
        canvas.drawCircle(head, 2.2 * s, Paint()..color = accent);
      }
    }

    // ── Start: an Ironclad ring ───────────────────────────────────────────
    final start = _start * s;
    canvas.drawCircle(
        start, 7 * s, Paint()..color = accent.withValues(alpha: 0.14));
    canvas.drawCircle(start, 4.6 * s, Paint()..color = iconPaper);
    canvas.drawCircle(
      start,
      4.6 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * s
        ..color = iconInk,
    );

    // ── The pin: drops onto the outlet's doorstep ─────────────────────────
    final drop = loopPhase(t, 0.48, 0.60, Curves.easeOutBack);
    if (drop > 0) {
      final ground = _end * s;
      final tip = Offset(ground.dx, ground.dy - (1 - drop) * 18 * s);

      // Arrival ripple on the ground.
      final ring = loopPhase(t, 0.58, 0.80, Curves.easeOut);
      if (ring > 0 && ring < 1) {
        canvas.drawOval(
          Rect.fromCenter(
              center: ground,
              width: (8 + 26 * ring) * s,
              height: (3 + 10 * ring) * s),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * s
            ..color = accent.withValues(alpha: 0.55 * (1 - ring)),
        );
      }
      // Shadow grows as the pin comes down.
      canvas.drawOval(
        Rect.fromCenter(
            center: ground, width: (6 + 6 * drop) * s, height: 3.2 * s),
        Paint()
          ..color = iconInk.withValues(alpha: 0.22 * drop)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * s),
      );
      _drawPin(canvas, tip, 9.5 * s);

      // ── Checked in ──────────────────────────────────────────────────────
      final badge = loopPhase(t, 0.64, 0.74, Curves.easeOutBack);
      if (badge > 0) {
        final c = Offset(tip.dx - 10 * s, tip.dy - 24 * s);
        canvas.drawCircle(c, 6.6 * s * badge, Paint()..color = iconPaper);
        canvas.drawCircle(c, 5.2 * s * badge, Paint()..color = iconGo);
        final tick = loopPhase(t, 0.68, 0.78);
        if (tick > 0) {
          final p = Path()
            ..moveTo(c.dx - 2.6 * s, c.dy + 0.2 * s)
            ..lineTo(c.dx - 0.7 * s, c.dy + 2.1 * s)
            ..lineTo(c.dx + 2.8 * s, c.dy - 1.9 * s);
          final m = p.computeMetrics().toList();
          final total = m.fold<double>(0, (a, b) => a + b.length);
          var left = tick * total;
          final drawn = Path();
          for (final seg in m) {
            if (left <= 0) break;
            drawn.addPath(
                seg.extractPath(0, math.min(left, seg.length)), Offset.zero);
            left -= seg.length;
          }
          canvas.drawPath(
            drawn,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8 * s
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = iconPaper,
          );
        }
      }
    }

    canvas.restore();
  }

  /// A soft rounded map tile with two faint streets: the ground the route is
  /// drawn on.
  void _mapTile(Canvas canvas, double s) {
    final tile = RRect.fromRectAndRadius(
      Rect.fromLTWH(8 * s, 10 * s, 84 * s, 82 * s),
      Radius.circular(20 * s),
    );
    canvas.drawRRect(tile, Paint()..color = accent.withValues(alpha: 0.07));
    canvas.save();
    canvas.clipRRect(tile);
    final street = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..color = iconPaper.withValues(alpha: 0.85);
    canvas.drawLine(Offset(0, 40 * s), Offset(100 * s, 22 * s), street);
    canvas.drawLine(Offset(34 * s, 100 * s), Offset(58 * s, 0), street);
    canvas.restore();
  }

  /// A modern shopfront: rounded body, scalloped awning in the accent.
  void _shop(Canvas canvas, double s, double scale) {
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(-5 * s, 0); // clear of the tile's right edge
    canvas.translate(80 * s, 54 * s);
    canvas.scale(scale);
    canvas.translate(-80 * s, -54 * s);

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(80 * s, 65 * s), width: 30 * s, height: 5 * s),
      Paint()
        ..color = iconInk.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(68 * s, 46 * s, 24 * s, 18 * s),
      Radius.circular(3.5 * s),
    );
    canvas.drawRRect(body, Paint()..color = iconPaper);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..color = iconInk,
    );
    // window and door
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(71.5 * s, 51 * s, 8 * s, 6 * s),
          Radius.circular(1.5 * s)),
      Paint()..color = iconShade,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(82.5 * s, 51 * s, 6 * s, 13 * s),
          Radius.circular(1.5 * s)),
      Paint()..color = accent.withValues(alpha: 0.35),
    );
    // scalloped awning
    final awning = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(66 * s, 40 * s, 28 * s, 6 * s),
          Radius.circular(2.5 * s)));
    for (var i = 0; i < 4; i++) {
      awning.addOval(Rect.fromCircle(
          center: Offset((69.5 + i * 7) * s, 46 * s), radius: 3.5 * s));
    }
    canvas.drawPath(awning, Paint()..color = accent);
    for (var i = 0; i < 2; i++) {
      canvas.drawRect(
        Rect.fromLTWH((73 + i * 14) * s, 40 * s, 7 * s, 6 * s),
        Paint()..color = iconPaper.withValues(alpha: 0.35),
      );
    }
    canvas.restore();
  }

  /// Teardrop pin whose point sits at [tip]; Ironclad into the accent.
  void _drawPin(Canvas canvas, Offset tip, double r) {
    final c = Offset(tip.dx, tip.dy - r * 1.9);
    final p = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..moveTo(c.dx - r * 0.66, c.dy + r * 0.75)
      ..quadraticBezierTo(c.dx, c.dy + r * 1.4, tip.dx, tip.dy)
      ..quadraticBezierTo(
          c.dx, c.dy + r * 1.4, c.dx + r * 0.66, c.dy + r * 0.75)
      ..close();
    canvas.drawPath(
      p.shift(Offset(0, r * 0.15)),
      Paint()
        ..color = iconInk.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, iconInk],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.6)),
    );
    canvas.drawCircle(c, r * 0.42, Paint()..color = iconPaper);
    // a small highlight, top-left
    canvas.drawCircle(
      Offset(c.dx - r * 0.45, c.dy - r * 0.5),
      r * 0.18,
      Paint()..color = iconPaper.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(VisitsIconPainter old) =>
      old.t != t || old.accent != accent;
}
