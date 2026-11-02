import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// Hand-drawn, gently animated icons for the My Work grid.
///
/// ## Why these are drawn rather than rendered artwork
///
/// The reference sheet's illustrations came with their colour baked into a
/// tile, and separating figure from ground broke them wherever the two shared
/// a hue. Drawing them means the background is transparent by construction,
/// every colour is a brand token, they stay crisp at any size, and — the part
/// artwork cannot do — they can *move*.
///
/// ## The motion is deliberately slow
///
/// Each icon runs a ~5 second cycle in which the action occupies barely two
/// seconds and the rest is stillness. Three looping animations sit on the home
/// screen permanently; anything brisker turns a work screen into a fairground.
/// The action reads once, then rests, which is what "calm" means in a tool
/// somebody opens forty times a day.
///
/// Every icon honours `MediaQuery.disableAnimations` by holding its finished
/// frame — the drawing carries the meaning, only the movement is optional.
enum WorkIconKind { visits, depots, quotesOrders }

class WorkIcon extends StatefulWidget {
  const WorkIcon({
    super.key,
    required this.kind,
    required this.accent,
    required this.size,
  });

  final WorkIconKind kind;
  final Color accent;
  final double size;

  @override
  State<WorkIcon> createState() => _WorkIconState();
}

class _WorkIconState extends State<WorkIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            // The frame every icon has finished on but none has begun to fade
            // from. It must sit after the *last* thing any of them draws —
            // the orders tick completes at 0.78 — and before the cycle fades
            // out at 0.90. Picking 0.62 (the moment the pin lands) left the
            // approval tick unstarted, so reduce-motion users saw a blank
            // green disc where the confirmation should be.
            final t = reduceMotion ? 0.84 : _loop.value;
            return CustomPaint(
              painter: switch (widget.kind) {
                WorkIconKind.visits =>
                  _VisitsPainter(t: t, accent: widget.accent),
                WorkIconKind.depots =>
                  _DepotsPainter(t: t, accent: widget.accent),
                WorkIconKind.quotesOrders =>
                  _OrdersPainter(t: t, accent: widget.accent),
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Shared drawing helpers ──────────────────────────────────────────────────

// Brand Guide §07 colours only.
const _ink = AppColors.brandNavy; // outlines — Ironclad Blue
const _paper = Color(0xFFFFFFFF); // fills that must read as "surface"
const _shade = AppColors.canvas; // soft secondary fill — Foundational White
const _go = AppColors.success; // confirmation — Sustainable Green

double _u(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);

/// Eases a value in over [start]..[end] of the loop.
double _phase(double t, double start, double end,
    [Curve curve = Curves.easeInOutCubic]) {
  if (end <= start) return 0;
  return curve.transform(_u((t - start) / (end - start)));
}

/// The whole icon fades down at the very end of the cycle and back up at the
/// start, so a loop never reads as a hard cut.
double _cycleOpacity(double t) {
  final out = 1 - _phase(t, 0.90, 1.00, Curves.easeIn);
  final into = _phase(t, 0.00, 0.06, Curves.easeOut);
  return (out * into).clamp(0.0, 1.0);
}

// ── My Visits ───────────────────────────────────────────────────────────────

/// A route tracing itself across a map tile to an outlet, a pin dropping on
/// it, then the visit checked off.
///
/// No captions: the earlier "Depot"/"Outlet" labels were 7pt English text
/// inside a drawing, unreadable at card size and untranslatable. The start
/// ring, the route and the shopfront say the same thing in any language.
class _VisitsPainter extends CustomPainter {
  _VisitsPainter({required this.t, required this.accent});

  final double t;
  final Color accent;

  static const _start = Offset(20, 80);
  static const _end = Offset(50, 66);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final o = _cycleOpacity(t);
    if (o <= 0.01) return;
    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: o));

    _mapTile(canvas, s);
    _shop(canvas, s, _phase(t, 0.04, 0.20, Curves.easeOutBack));

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
    final travelled = _phase(t, 0.16, 0.50, Curves.easeInOutCubic);
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
          ..shader = LinearGradient(colors: [_ink, accent]).createShader(
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
        canvas.drawCircle(head, 3.4 * s, Paint()..color = _paper);
        canvas.drawCircle(head, 2.2 * s, Paint()..color = accent);
      }
    }

    // ── Start: an Ironclad ring ───────────────────────────────────────────
    final start = _start * s;
    canvas.drawCircle(
        start, 7 * s, Paint()..color = accent.withValues(alpha: 0.14));
    canvas.drawCircle(start, 4.6 * s, Paint()..color = _paper);
    canvas.drawCircle(
      start,
      4.6 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * s
        ..color = _ink,
    );

    // ── The pin: drops onto the outlet's doorstep ─────────────────────────
    final drop = _phase(t, 0.48, 0.60, Curves.easeOutBack);
    if (drop > 0) {
      final ground = _end * s;
      final tip = Offset(ground.dx, ground.dy - (1 - drop) * 18 * s);

      // Arrival ripple on the ground.
      final ring = _phase(t, 0.58, 0.80, Curves.easeOut);
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
          ..color = _ink.withValues(alpha: 0.22 * drop)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * s),
      );
      _drawPin(canvas, tip, 9.5 * s);

      // ── Checked in ──────────────────────────────────────────────────────
      final badge = _phase(t, 0.64, 0.74, Curves.easeOutBack);
      if (badge > 0) {
        final c = Offset(tip.dx - 10 * s, tip.dy - 24 * s);
        canvas.drawCircle(c, 6.6 * s * badge, Paint()..color = _paper);
        canvas.drawCircle(c, 5.2 * s * badge, Paint()..color = _go);
        final tick = _phase(t, 0.68, 0.78);
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
              ..color = _paper,
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
      ..color = _paper.withValues(alpha: 0.85);
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
        ..color = _ink.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(68 * s, 46 * s, 24 * s, 18 * s),
      Radius.circular(3.5 * s),
    );
    canvas.drawRRect(body, Paint()..color = _paper);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..color = _ink,
    );
    // window and door
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(71.5 * s, 51 * s, 8 * s, 6 * s),
          Radius.circular(1.5 * s)),
      Paint()..color = _shade,
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
        Paint()..color = _paper.withValues(alpha: 0.35),
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
        ..color = _ink.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, _ink],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.6)),
    );
    canvas.drawCircle(c, r * 0.42, Paint()..color = _paper);
    // a small highlight, top-left
    canvas.drawCircle(
      Offset(c.dx - r * 0.45, c.dy - r * 0.5),
      r * 0.18,
      Paint()..color = _paper.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_VisitsPainter old) => old.t != t || old.accent != accent;
}

// ── My Depots ────────────────────────────────────────────────────────────

/// Three figures gathering, then a contact card settling in front.
class _DepotsPainter extends CustomPainter {
  _DepotsPainter({required this.t, required this.accent});

  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final o = _cycleOpacity(t);
    if (o <= 0.01) return;
    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: o));

    // Back figures first, staggered — a small crowd assembling, not popping.
    _figure(canvas, s, Offset(28 * s, 44 * s), 9 * s,
        accent.withValues(alpha: 0.45), _phase(t, 0.06, 0.30, Curves.easeOut));
    _figure(canvas, s, Offset(72 * s, 44 * s), 9 * s,
        accent.withValues(alpha: 0.30), _phase(t, 0.12, 0.36, Curves.easeOut));
    // The main depot, front and centre.
    _figure(canvas, s, Offset(50 * s, 38 * s), 13 * s, accent,
        _phase(t, 0.00, 0.26, Curves.easeOutBack));

    // ── Contact card ──────────────────────────────────────────────────────
    final card = _phase(t, 0.34, 0.56, Curves.easeOutBack);
    if (card > 0) {
      canvas.save();
      // Rises into place rather than fading: it reads as being handed over.
      canvas.translate(0, (1 - card) * 10 * s);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(24 * s, 66 * s, 52 * s, 24 * s),
        Radius.circular(5 * s),
      );
      canvas.drawRRect(rect, Paint()..color = _paper);
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * s
          ..color = _ink,
      );
      // avatar chip
      canvas.drawCircle(
          Offset(36 * s, 78 * s), 5.5 * s, Paint()..color = accent);
      // two detail lines, drawn left to right
      final lines = _phase(t, 0.44, 0.66);
      for (var i = 0; i < 2; i++) {
        final w = (20 - i * 6) * s * lines;
        if (w <= 0) continue;
        canvas.drawLine(
          Offset(47 * s, (74 + i * 8) * s),
          Offset(47 * s + w, (74 + i * 8) * s),
          Paint()
            ..strokeWidth = 3 * s
            ..strokeCap = StrokeCap.round
            ..color = _shade,
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
  bool shouldRepaint(_DepotsPainter old) => old.t != t || old.accent != accent;
}

// ── My Quotes & Orders ──────────────────────────────────────────────────────

/// A quotation writing itself, then being approved.
class _OrdersPainter extends CustomPainter {
  _OrdersPainter({required this.t, required this.accent});

  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final o = _cycleOpacity(t);
    if (o <= 0.01) return;
    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: o));

    // ── The sheet ─────────────────────────────────────────────────────────
    final sheetIn = _phase(t, 0.00, 0.20, Curves.easeOutBack);
    if (sheetIn > 0) {
      canvas.save();
      canvas.translate(50 * s, 50 * s);
      canvas.scale(sheetIn);
      canvas.translate(-50 * s, -50 * s);

      final sheet = RRect.fromRectAndRadius(
        Rect.fromLTWH(22 * s, 12 * s, 50 * s, 66 * s),
        Radius.circular(6 * s),
      );
      canvas.drawRRect(sheet, Paint()..color = _paper);
      canvas.drawRRect(
        sheet,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * s
          ..color = _ink,
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
      final w = widths[i] * s * _phase(t, start, start + 0.12);
      if (w <= 0) continue;
      canvas.drawLine(
        Offset(30 * s, (37 + i * 10) * s),
        Offset(30 * s + w, (37 + i * 10) * s),
        Paint()
          ..strokeWidth = 3.4 * s
          ..strokeCap = StrokeCap.round
          ..color = _shade,
      );
    }

    // ── Approval ──────────────────────────────────────────────────────────
    final stamp = _phase(t, 0.56, 0.70, Curves.easeOutBack);
    if (stamp > 0) {
      final c = Offset(70 * s, 70 * s);
      canvas.drawCircle(c, 17 * s * stamp, Paint()..color = _paper);
      canvas.drawCircle(c, 15 * s * stamp, Paint()..color = _go);

      // The tick draws rather than appears — the moment of approval, not a
      // sticker dropped on top.
      final tick = _phase(t, 0.62, 0.78);
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
            ..color = _paper,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrdersPainter old) => old.t != t || old.accent != accent;
}
