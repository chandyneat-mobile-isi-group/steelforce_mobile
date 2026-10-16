import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/calendar_month_icon.dart';

/// The icon is drawn entirely in a `CustomPainter`, where the failure modes are
/// arithmetic rather than structural — a `t` outside 0–1 producing NaN, a
/// negative rect width from a clamp that was not applied, a zero-size canvas
/// during layout. None of that shows up in static analysis, and all of it
/// throws on the home screen, which is the first thing every rep sees.
///
/// This is a crash net, not a judgement of how the animation looks.
void main() {
  const accent = Color(0xFF2563EB);
  const ink = Color(0xFF334155);
  const muted = Color(0xFF94A3B8);

  Widget frame(Widget child, {Size size = const Size(40, 40)}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        ),
      );

  Widget paintedAt(double t) => CustomPaint(
        painter: CalendarMonthPainter(
          t: t,
          accent: accent,
          ink: ink,
          muted: muted,
        ),
      );

  testWidgets('paints at every point of its cycle', (tester) async {
    for (var i = 0; i <= 60; i++) {
      final t = i / 60;
      await tester.pumpWidget(frame(paintedAt(t)));
      expect(tester.takeException(), isNull, reason: 'threw at t=$t');
    }
  });

  testWidgets('survives values outside its documented range', (tester) async {
    // The controller only ever supplies 0–1, but a painter that divides by a
    // phase window is one arithmetic slip away from NaN, and `_u` exists to
    // absorb exactly this. Assert it does.
    for (final t in const [-1.0, -0.01, 1.01, 2.0, 1000.0, double.nan]) {
      await tester.pumpWidget(frame(paintedAt(t)));
      expect(tester.takeException(), isNull, reason: 'threw at t=$t');
    }
  });

  testWidgets('paints at a range of sizes without throwing', (tester) async {
    // 20pt is what the medallion asks for; the extremes bracket a 200%
    // text-scale medallion and a degenerate layout pass.
    for (final side in const [0.0, 1.0, 8.0, 20.0, 48.0, 200.0]) {
      await tester.pumpWidget(frame(paintedAt(0.5), size: Size(side, side)));
      expect(tester.takeException(), isNull, reason: 'threw at size=$side');
    }
  });

  group('the widget', () {
    testWidgets('mounts, animates and disposes cleanly', (tester) async {
      await tester.pumpWidget(frame(const CalendarMonthIcon(
        size: 20,
        accent: accent,
        ink: ink,
        muted: muted,
      )));

      // Drive it through a full cycle in steps. A leaked controller or a throw
      // mid-cycle surfaces here.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.takeException(), isNull);
      }

      // Unmount: an undisposed AnimationController fails the test binding.
      await tester.pumpWidget(frame(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('holds a finished frame under reduce-motion', (tester) async {
      // FS-ANI-7. The drawing carries the meaning; only the movement is
      // optional — so the held frame must be one where the month is drawn and
      // the day is marked, not a half-drawn one.
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: const CalendarMonthIcon(
                size: 20,
                accent: accent,
                ink: ink,
                muted: muted,
              ),
            ),
          ),
        ),
      ));

      final painter = tester
          .widget<CustomPaint>(find.descendant(
            of: find.byType(CalendarMonthIcon),
            matching: find.byType(CustomPaint),
          ))
          .painter as CalendarMonthPainter;

      // Past the marker landing (0.76), before the fade-out (0.90).
      expect(painter.t, greaterThan(0.76));
      expect(painter.t, lessThan(0.90));

      // And it stays put rather than advancing.
      await tester.pump(const Duration(seconds: 2));
      final after = tester
          .widget<CustomPaint>(find.descendant(
            of: find.byType(CalendarMonthIcon),
            matching: find.byType(CustomPaint),
          ))
          .painter as CalendarMonthPainter;
      expect(after.t, painter.t);
    });
  });

  group('shouldRepaint', () {
    CalendarMonthPainter p({
      double t = 0.5,
      Color a = accent,
      Color i = ink,
      Color m = muted,
    }) =>
        CalendarMonthPainter(t: t, accent: a, ink: i, muted: m);

    test('repaints when the frame or any colour changes', () {
      expect(p().shouldRepaint(p(t: 0.6)), isTrue);
      expect(p().shouldRepaint(p(a: const Color(0xFF000000))), isTrue);
      expect(p().shouldRepaint(p(i: const Color(0xFF000000))), isTrue);
      expect(p().shouldRepaint(p(m: const Color(0xFF000000))), isTrue);
    });

    test('does not repaint when nothing changed', () {
      // This runs every frame of a permanent loop; returning true
      // unconditionally would repaint the whole medallion for no reason.
      expect(p().shouldRepaint(p()), isFalse);
    });
  });
}
