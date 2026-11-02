import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';

/// Shared building blocks for the splash story's scenes.
///
/// Every scene is a pure function of a single `t` in 0–1 supplied by
/// `SplashTimeline`. None owns a controller, none owns state, and none knows
/// what comes before or after it — which is what lets the story be re-timed by
/// editing one interval table instead of renegotiating seven widgets.
///
/// The palette is light throughout: the story plays on white, so every surface
/// here is an opaque card with a real border, not a translucent "glass" panel.
/// Frosted panels need something dark behind them to read at all; on white they
/// disappear.

// ── Palette shared by the scenes ────────────────────────────────────────────
const _ink = Color(0xFF1E293B); // slate — primary text
const _muted = Color(0xFF64748B); // secondary text
const _hairline = Color(0xFFE2E8F0); // borders, road casing
const _blockFill = Color(0xFFEEF2F6); // map blocks

/// Wraps a scene in its entry and exit.
///
/// Scenes rise slightly, fade in, hold, then fade and sink as the next takes
/// over. The vertical travel is deliberately small (10px): the tell of the
/// Apple-like motion the brief asks for is that things move *less* than you
/// expect, not more.
class SceneShell extends StatelessWidget {
  const SceneShell({super.key, required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Quick in, long hold, quick out. With sequential scene windows the hold is
    // the majority of the beat — that hold is what "one at a time" means.
    final fadeIn = Curves.easeOut.transform(_u(t / 0.16));
    final fadeOut = 1 - Curves.easeIn.transform(_u((t - 0.86) / 0.14));
    final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
    if (opacity <= 0.01) return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, (1 - fadeIn) * 10 - (1 - fadeOut) * 10),
          child: child,
        ),
      ),
    );
  }
}

/// The card style every scene uses.
///
/// One card across four scenes is what makes the route card, the visit card and
/// the order rows read as the *same application* rather than three unrelated
/// illustrations.
class SceneCard extends StatelessWidget {
  const SceneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Scene 2 — the route, on a map
// ────────────────────────────────────────────────────────────────────────────

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
              opacity: _u((t - 0.62) / 0.24),
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
                        children: [
                          SceneText('onboarding.story.selected_route'.tr,
                              size: 9,
                              color: _muted,
                              weight: FontWeight.w800,
                              align: TextAlign.left),
                          const SizedBox(height: 3),
                          SceneText(
                              'onboarding.story.route_summary'
                                  .trParams({'count': 5}),
                              size: 14,
                              color: _ink,
                              weight: FontWeight.w800,
                              align: TextAlign.left),
                        ],
                      ),
                    ),
                    const SceneText('12.4 km',
                        size: 12, color: _muted, weight: FontWeight.w700),
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
    final blockPaint = Paint()..color = _blockFill;
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
      ..color = _hairline
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
    final travelled = Curves.easeInOutCubic.transform(_u((t - 0.18) / 0.52));
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
        ..color = _muted,
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
    final arrived = Curves.easeOutBack.transform(_u((travelled - 0.88) / 0.12));
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

// ────────────────────────────────────────────────────────────────────────────
// Scene 3 — arrival and check-in
// ────────────────────────────────────────────────────────────────────────────

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
    final press = _u((t - 0.74) / 0.16);
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
                  SceneText('onboarding.story.depot_visit'.tr,
                      size: 9, color: _muted, weight: FontWeight.w800),
                  const SizedBox(height: 7),
                  const SceneText('Sok Dara Hardware',
                      size: 16, color: _ink, weight: FontWeight.w800),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 13, color: success),
                      const SizedBox(width: 5),
                      SceneText('onboarding.story.location_verified'.tr,
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
              child: SceneText('onboarding.story.start_visit'.tr,
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
      final ring = _u((t - 0.18 - i * 0.15) / 0.55);
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

    final pin = Curves.easeOutBack.transform(_u(t / 0.28));
    canvas.drawCircle(
        centre, 26 * pin, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.drawCircle(centre, 11 * pin, Paint()..color = Colors.white);
    canvas.drawCircle(centre, 8 * pin, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_GeofencePainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// Scene 4 — the quotation
// ────────────────────────────────────────────────────────────────────────────

/// Products chosen, priced, discounted, approved.
class OrderScene extends StatelessWidget {
  const OrderScene({
    super.key,
    required this.t,
    required this.accent,
    required this.success,
  });

  final double t;
  final Color accent, success;

  static const _rows = [
    ('Deformed Bar D12', 'x 120', r'$ 8,640'),
    ('H-Beam 200×100', 'x 24', r'$ 5,280'),
    ('Steel Sheet 4mm', 'x 60', r'$ 3,150'),
  ];

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      t: t,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SceneText('onboarding.story.create_quotation'.tr,
                  size: 9, color: _muted, weight: FontWeight.w800),
              const SizedBox(height: 16),
              // Rows arrive one at a time — three of them, well inside the ≤6
              // the motion standard allows before a stagger reads as broken.
              for (var i = 0; i < _rows.length; i++)
                _ProductRow(
                  t: _u((t - 0.08 - i * 0.15) / 0.34),
                  name: _rows[i].$1,
                  qty: _rows[i].$2,
                  price: _rows[i].$3,
                ),
              const SizedBox(height: 14),
              // The approval branch of the brief's two workflows, compressed to
              // its one legible beat.
              Opacity(
                opacity: _u((t - 0.66) / 0.20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Chip(
                      'onboarding.story.discount'.trParams({'percent': 6}),
                      accent,
                    ),
                    const SizedBox(width: 8),
                    _Chip('onboarding.story.approved'.tr, success),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.t,
    required this.name,
    required this.qty,
    required this.price,
  });

  final double t;
  final String name, qty, price;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(24 * (1 - eased), 0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: SceneCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _blockFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.layers_rounded, size: 15, color: _muted),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: SceneText(name,
                      size: 12,
                      color: _ink,
                      weight: FontWeight.w700,
                      align: TextAlign.left),
                ),
                SceneText(qty, size: 11, color: _muted),
                const SizedBox(width: 10),
                SceneText(price,
                    size: 12, color: _ink, weight: FontWeight.w800),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: SceneText(text, size: 10, color: color, weight: FontWeight.w800),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Scene 5 — confirmation
// ────────────────────────────────────────────────────────────────────────────

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
              opacity: _u((t - 0.50) / 0.28),
              child: SceneText('onboarding.story.order_created'.tr,
                  size: 15, color: _ink, weight: FontWeight.w900),
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
    final ring = Curves.easeOutCubic.transform(_u(t / 0.46));
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

    final tick = Curves.easeOutCubic.transform(_u((t - 0.40) / 0.34));
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

/// Text helper for the scenes.
///
/// Deliberately not themed: these are illustrations that always play on the
/// white story backdrop, so their colours must not follow the app's light/dark
/// setting — a dark-mode swap here would render them invisible.
class SceneText extends StatelessWidget {
  const SceneText(
    this.text, {
    super.key,
    required this.size,
    required this.color,
    this.weight = FontWeight.w600,
    this.align = TextAlign.center,
  });

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0.5,
        height: 1.2,
      ),
    );
  }
}

double _u(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
