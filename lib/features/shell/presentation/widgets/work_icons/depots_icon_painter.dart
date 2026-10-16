import 'package:flutter/material.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/work_icon_drawing.dart';

/// Three figures gathering, then a contact card settling in front.
class DepotsIconPainter extends CustomPainter {
  DepotsIconPainter({required this.t, required this.accent});

  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final o = loopCycleOpacity(t);
    if (o <= 0.01) return;
    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: o));

    // Back figures first, staggered — a small crowd assembling, not popping.
    _figure(
        canvas,
        s,
        Offset(28 * s, 44 * s),
        9 * s,
        accent.withValues(alpha: 0.45),
        loopPhase(t, 0.06, 0.30, Curves.easeOut));
    _figure(
        canvas,
        s,
        Offset(72 * s, 44 * s),
        9 * s,
        accent.withValues(alpha: 0.30),
        loopPhase(t, 0.12, 0.36, Curves.easeOut));
    // The main depot, front and centre.
    _figure(canvas, s, Offset(50 * s, 38 * s), 13 * s, accent,
        loopPhase(t, 0.00, 0.26, Curves.easeOutBack));

    // ── Contact card ──────────────────────────────────────────────────────
    final card = loopPhase(t, 0.34, 0.56, Curves.easeOutBack);
    if (card > 0) {
      canvas.save();
      // Rises into place rather than fading: it reads as being handed over.
      canvas.translate(0, (1 - card) * 10 * s);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(24 * s, 66 * s, 52 * s, 24 * s),
        Radius.circular(5 * s),
      );
      canvas.drawRRect(rect, Paint()..color = iconPaper);
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * s
          ..color = iconInk,
      );
      // avatar chip
      canvas.drawCircle(
          Offset(36 * s, 78 * s), 5.5 * s, Paint()..color = accent);
      // two detail lines, drawn left to right
      final lines = loopPhase(t, 0.44, 0.66);
      for (var i = 0; i < 2; i++) {
        final w = (20 - i * 6) * s * lines;
        if (w <= 0) continue;
        canvas.drawLine(
          Offset(47 * s, (74 + i * 8) * s),
          Offset(47 * s + w, (74 + i * 8) * s),
          Paint()
            ..strokeWidth = 3 * s
            ..strokeCap = StrokeCap.round
            ..color = iconShade,
        );
      }
      canvas.restore();
    }

    canvas.restore();
  }

  void _figure(
      Canvas canvas, double s, Offset head, double r, Color color, double in_) {
    if (in_ <= 0) return;
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.scale(in_);
    canvas.translate(-head.dx, -head.dy);
    canvas.drawCircle(head, r, Paint()..color = color);
    // shoulders
    final body =
        Rect.fromLTWH(head.dx - r * 1.5, head.dy + r * 0.7, r * 3, r * 2.4);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        body,
        topLeft: Radius.circular(r * 1.5),
        topRight: Radius.circular(r * 1.5),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DepotsIconPainter old) =>
      old.t != t || old.accent != accent;
}
