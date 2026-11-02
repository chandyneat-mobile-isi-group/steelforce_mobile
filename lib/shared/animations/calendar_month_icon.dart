import 'package:flutter/material.dart';

/// A calendar that draws its month in, then marks the current day.
///
/// ## Why drawn rather than `Icons.calendar_today_rounded`
///
/// The glyph it replaces is a static outline: it names the card but says
/// nothing. Drawn, the same 36pt medallion can show a month *filling in* and a
/// day being marked — which is the card's subject. That satisfies FS-ANI-4
/// (motion explains something) rather than decorating for its own sake.
///
/// Nothing here is data-bound. The grid is a fixed twelve cells and the marker
/// always lands on the same one; it is an icon, not a chart. Binding it to a
/// real day count would make it a second, quieter progress indicator competing
/// with the bar and the percentage pill directly beneath it — and inventing a
/// figure to fill it would be exactly the fabricated-data trap FS-NN-5 names.
///
/// ## The motion is deliberately slow
///
/// Same reasoning as [WorkIcon], which this deliberately matches: a ~5s cycle
/// where the action occupies roughly the first two seconds and the rest is
/// stillness. This sits on the home screen permanently, beside three other
/// looping icons. Anything brisker turns a work surface into a fairground.
///
/// Honours `MediaQuery.disableAnimations` by holding the finished frame — the
/// drawing carries the meaning, only the movement is optional (FS-ANI-7).
class CalendarMonthIcon extends StatefulWidget {
  const CalendarMonthIcon({
    super.key,
    required this.size,
    required this.accent,
    required this.ink,
    required this.muted,
  });

  final double size;

  /// Header block and the day marker — the brand colour.
  final Color accent;

  /// Outlines and the calendar body. Passed in rather than baked so the icon
  /// stays legible when `scheme.surface` flips in dark mode.
  final Color ink;

  /// Unmarked day cells.
  final Color muted;

  @override
  State<CalendarMonthIcon> createState() => _CalendarMonthIconState();
}

class _CalendarMonthIconState extends State<CalendarMonthIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  /// Not an `AppDurations` token deliberately. Those describe *interaction*
  /// feedback — a press, an entrance, a page change — and top out at 350ms.
  /// This is an ambient loop, a different kind of motion with a different
  /// constraint: long enough that the eye is not pulled back to it. Matches
  /// `WorkIcon`'s 5200ms so the four looping icons on the home screen do not
  /// beat against each other.
  static const Duration _cycle = Duration(milliseconds: 5200);

  /// The frame reduce-motion holds: after the day marker has landed (0.76) and
  /// before the cycle fades out (0.90). Parking earlier would freeze the icon
  /// mid-draw, showing an unmarked half-empty month as if that were the icon.
  static const double _restFrame = 0.82;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: _cycle)..repeat();
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
          builder: (context, _) => CustomPaint(
            painter: CalendarMonthPainter(
              t: reduceMotion ? _restFrame : _loop.value,
              accent: widget.accent,
              ink: widget.ink,
              muted: widget.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Drawing helpers ─────────────────────────────────────────────────────────
//
// Deliberately duplicated from `work_icons.dart` rather than shared. Those
// three helpers are private there, the file has no test covering 473 lines of
// painter arithmetic, and lifting them out blind would put an untested
// refactor underneath the home screen. Worth extracting once that file has a
// crash net of its own.

double _u(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);

/// Eases a value in over [start]..[end] of the loop.
double _phase(double t, double start, double end,
    [Curve curve = Curves.easeInOutCubic]) {
  if (end <= start) return 0;
  return curve.transform(_u((t - start) / (end - start)));
}

/// The icon fades down at the very end of the cycle and back up at the start,
/// so a loop never reads as a hard cut.
double _cycleOpacity(double t) {
  final out = 1 - _phase(t, 0.90, 1.00, Curves.easeIn);
  final into = _phase(t, 0.00, 0.06, Curves.easeOut);
  return _u(out * into);
}

/// Paints the calendar at a point [t] in its 0–1 cycle.
///
/// Public so the crash-net test can drive it across the whole range without
/// pumping a controller — the failure modes here are arithmetic (NaN from a
/// zero-length phase, a negative rect width) and never surface in analysis.
class CalendarMonthPainter extends CustomPainter {
  CalendarMonthPainter({
    required this.t,
    required this.accent,
    required this.ink,
    required this.muted,
  });

  final double t;
  final Color accent;
  final Color ink;
  final Color muted;

  /// Twelve cells: four columns, three rows. Not a real month — see the class
  /// doc on [CalendarMonthIcon].
  static const int _columns = 4;
  static const int _rows = 3;

  /// Which cell the marker lands on. Second column, middle row: visually
  /// central without sitting dead centre, which reads as a bullseye.
  static const int _markedCell = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Everything below is authored in a 100×100 space and scaled once.
    final s = size.width / 100.0;
    final o = _cycleOpacity(t);
    if (o <= 0.01) return;

    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: o));

    _paintRings(canvas, s);
    _paintBody(canvas, s);

    canvas.restore();
  }

  /// The two binding rings, dropping in from above the body.
  void _paintRings(Canvas canvas, double s) {
    final drop = _phase(t, 0.10, 0.26, Curves.easeOutCubic);
    if (drop <= 0) return;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round
      ..color = ink;

    // Travels the last 10 units into place rather than appearing at rest.
    final y = 12 * s + (1 - drop) * -10 * s;
    for (final x in const [34.0, 66.0]) {
      canvas.drawLine(Offset(x * s, y), Offset(x * s, y + 14 * s), stroke);
    }
  }

  void _paintBody(Canvas canvas, double s) {
    // easeOutBack: the body settles with a slight overshoot, which is what
    // makes it read as *placed* rather than faded in.
    final scale = _phase(t, 0.02, 0.22, Curves.easeOutBack);
    if (scale <= 0) return;

    final rect = Rect.fromLTWH(12 * s, 22 * s, 76 * s, 66 * s);
    final centre = rect.center;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(scale);
    canvas.translate(-centre.dx, -centre.dy);

    final body = RRect.fromRectAndRadius(rect, Radius.circular(9 * s));

    canvas.drawRRect(body, Paint()..color = muted.withValues(alpha: 0.35));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * s
        ..color = ink,
    );

    _paintHeader(canvas, s, rect);
    _paintDays(canvas, s, rect);

    canvas.restore();
  }

  /// The accent header, wiping left to right.
  void _paintHeader(Canvas canvas, double s, Rect body) {
    final wipe = _phase(t, 0.20, 0.34, Curves.easeOutCubic);
    if (wipe <= 0) return;

    final full = Rect.fromLTWH(body.left, body.top, body.width, 18 * s);
    // `wipe` is clamped to 0–1, so the width can never go negative.
    final grown =
        Rect.fromLTWH(full.left, full.top, full.width * wipe, full.height);

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndCorners(
      body,
      topLeft: Radius.circular(7 * s),
      topRight: Radius.circular(7 * s),
    ));
    canvas.drawRect(grown, Paint()..color = accent);
    canvas.restore();
  }

  /// Day cells filling in, then one of them marked.
  void _paintDays(Canvas canvas, double s, Rect body) {
    const cellCount = _columns * _rows;

    final left = body.left + 12 * s;
    final top = body.top + 30 * s;
    final stepX = (body.width - 24 * s) / (_columns - 1);
    final stepY = (body.height - 42 * s) / (_rows - 1);
    final radius = 4.5 * s;

    for (var i = 0; i < cellCount; i++) {
      // Staggered across 0.30–0.64, each cell easing in over its own slice.
      final start = 0.30 + (i / cellCount) * 0.28;
      final appear = _phase(t, start, start + 0.10, Curves.easeOutCubic);
      if (appear <= 0) continue;

      final centre = Offset(
        left + (i % _columns) * stepX,
        top + (i ~/ _columns) * stepY,
      );

      final isMarked = i == _markedCell;

      canvas.drawCircle(
        centre,
        radius * appear,
        Paint()..color = (isMarked ? accent : muted).withValues(alpha: 0.85),
      );

      if (!isMarked) continue;

      // The marker ring lands last, with an overshoot — the one beat the whole
      // cycle builds to.
      final land = _phase(t, 0.62, 0.76, Curves.easeOutBack);
      if (land <= 0) continue;

      canvas.drawCircle(
        centre,
        (radius + 4 * s) * land,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * s
          ..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(CalendarMonthPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.ink != ink ||
      old.muted != muted;
}
