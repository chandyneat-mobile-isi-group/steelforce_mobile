import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/work_icon_drawing.dart';

/// A quotation writing itself, then being approved.
class OrdersIconPainter extends CustomPainter {
  OrdersIconPainter({required this.t, required this.accent});

  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final o = loopCycleOpacity(t);
    if (o <= 0.01) return;
    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: o));

    // ── The sheet ─────────────────────────────────────────────────────────
    final sheetIn = loopPhase(t, 0.00, 0.20, Curves.easeOutBack);
    if (sheetIn > 0) {
      canvas.save();
      canvas.translate(50 * s, 50 * s);
      canvas.scale(sheetIn);
      canvas.translate(-50 * s, -50 * s);

      final sheet = RRect.fromRectAndRadius(
        Rect.fromLTWH(22 * s, 12 * s, 50 * s, 66 * s),
        Radius.circular(6 * s),
      );
      canvas.drawRRect(sheet, Paint()..color = iconPaper);
      canvas.drawRRect(
        sheet,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * s
          ..color = iconInk,
      );
      // header band — the quotation's title block
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(30 * s, 21 * s, 26 * s, 6 * s),
          Radius.circular(3 * s),
        ),
        Paint()..color = accent,
      );
      canvas.restore();
    }

    // ── Line items, written one at a time ─────────────────────────────────
    // Sequential rather than simultaneous: a quotation is built up line by
    // line, and staggering is what makes the icon read as *composing* one.
    const widths = [30.0, 24.0, 27.0];
    for (var i = 0; i < widths.length; i++) {
      final start = 0.22 + i * 0.09;
      final w = widths[i] * s * loopPhase(t, start, start + 0.12);
      if (w <= 0) continue;
      canvas.drawLine(
        Offset(30 * s, (37 + i * 10) * s),
        Offset(30 * s + w, (37 + i * 10) * s),
        Paint()
          ..strokeWidth = 3.4 * s
          ..strokeCap = StrokeCap.round
          ..color = iconShade,
      );
    }

    // ── Approval ──────────────────────────────────────────────────────────
    final stamp = loopPhase(t, 0.56, 0.70, Curves.easeOutBack);
    if (stamp > 0) {
      final c = Offset(70 * s, 70 * s);
      canvas.drawCircle(c, 17 * s * stamp, Paint()..color = iconPaper);
      canvas.drawCircle(c, 15 * s * stamp, Paint()..color = iconGo);

      // The tick draws rather than appears — the moment of approval, not a
      // sticker dropped on top.
      final tick = loopPhase(t, 0.62, 0.78);
      if (tick > 0) {
        final p = Path()
          ..moveTo(c.dx - 7 * s, c.dy)
          ..lineTo(c.dx - 2 * s, c.dy + 5.5 * s)
          ..lineTo(c.dx + 7.5 * s, c.dy - 5.5 * s);
        final segs = p.computeMetrics().toList();
        final total = segs.fold<double>(0, (a, b) => a + b.length);
        final drawn = Path();
        var left = tick * total;
        for (final seg in segs) {
          if (left <= 0) break;
          drawn.addPath(
              seg.extractPath(0, math.min(left, seg.length)), Offset.zero);
          left -= seg.length;
        }
        canvas.drawPath(
          drawn,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6 * s
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = iconPaper,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(OrdersIconPainter old) =>
      old.t != t || old.accent != accent;
}
