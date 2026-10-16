import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/calendar_month_icon.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/work_icon.dart';

/// Crash net and reference frames for the My Work grid icons.
///
/// The icons are drawn in `CustomPainter`s whose failure modes are arithmetic
/// (NaN from a phase window, an empty path metric), invisible to analysis.
/// The goldens pin exactly what each icon draws at a few points of its loop,
/// so a restructure of the painters cannot quietly change a pixel.
void main() {
  const accent = Color(0xFF2563EB);
  const loop = Duration(milliseconds: 5200);

  Widget frame(Widget child, {bool reduceMotion = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ColoredBox(
              color: Colors.white,
              child: child,
            ),
          ),
        ),
      );

  Duration at(double t) =>
      Duration(microseconds: (loop.inMicroseconds * t).round());

  for (final kind in WorkIconKind.values) {
    testWidgets('${kind.name} paints across its whole loop', (tester) async {
      await tester.pumpWidget(
        frame(WorkIcon(kind: kind, accent: accent, size: 64)),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(at(1 / 40));
        expect(tester.takeException(), isNull, reason: '${kind.name} at $i');
      }
    });

    for (final t in const [0.15, 0.40, 0.70]) {
      testWidgets('golden_${kind.name}_$t', (tester) async {
        await tester.pumpWidget(
          frame(WorkIcon(kind: kind, accent: accent, size: 120)),
        );
        await tester.pump(at(t));
        await expectLater(
          find.byType(WorkIcon),
          matchesGoldenFile('goldens/work_icon_${kind.name}_$t.png'),
        );
      });
    }

    testWidgets('golden_${kind.name}_reduced_motion', (tester) async {
      await tester.pumpWidget(
        frame(
          WorkIcon(kind: kind, accent: accent, size: 120),
          reduceMotion: true,
        ),
      );
      await tester.pump(at(0.3));
      await expectLater(
        find.byType(WorkIcon),
        matchesGoldenFile('goldens/work_icon_${kind.name}_still.png'),
      );
    });
  }

  for (final t in const [0.15, 0.50, 0.95]) {
    testWidgets('golden_calendar_$t', (tester) async {
      await tester.pumpWidget(
        frame(
          SizedBox.square(
            dimension: 120,
            child: CustomPaint(
              painter: CalendarMonthPainter(
                t: t,
                accent: accent,
                ink: const Color(0xFF334155),
                muted: const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(CustomPaint).last,
        matchesGoldenFile('goldens/calendar_month_$t.png'),
      );
    });
  }
}
