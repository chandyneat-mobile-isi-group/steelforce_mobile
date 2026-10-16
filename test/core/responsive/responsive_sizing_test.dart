import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Mirrors `app.dart`: compact keeps the 390x844 phone design, wider windows
/// use the real viewport so ScreenUtil's scale factor becomes 1.0.
Future<T> at<T>(
  WidgetTester tester,
  double width,
  T Function(BuildContext) read,
) async {
  // `.h` scales by the HEIGHT ratio, so the viewport height must match the
  // design height or compact would not come out 1:1.
  final height = width < 600 ? 844.0 : 1000.0;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);

  late T out;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: width < 600 ? const Size(390, 844) : Size(width, height),
      builder: (context, _) => Builder(builder: (c) {
        out = read(c);
        return const SizedBox();
      }),
    ),
  );
  await tester.pump();
  return out;
}

void main() {
  testWidgets('compact is the untouched mobile baseline', (tester) async {
    // A 390pt phone: design size == viewport, so ScreenUtil's factor is 1.0 and
    // every helper must return the raw design number it replaced.
    expect(await at(tester, 390, (c) => c.boxScale), 1.0);
    expect(await at(tester, 390, (c) => c.typeScale), 1.0);
    expect(await at(tester, 390, (c) => c.rh(124)), closeTo(124, 0.01));
    expect(await at(tester, 390, (c) => c.rr(48)), closeTo(48, 0.01));
    expect(await at(tester, 390, (c) => c.rsp(14)), closeTo(14, 0.01));
    expect(await at(tester, 390, (c) => c.pagePadding), closeTo(16, 0.01));
  });

  testWidgets('tablet/desktop step up both boxes and type', (tester) async {
    for (final w in [834.0, 1032.0, 1440.0]) {
      final box = await at(tester, w, (c) => c.boxScale);
      final type = await at(tester, w, (c) => c.typeScale);
      final card = await at(tester, w, (c) => c.rh(124));
      final label = await at(tester, w, (c) => c.rsp(14));
      final pad = await at(tester, w, (c) => c.pagePadding);
      // ignore: avoid_print
      print('${w.toStringAsFixed(0).padLeft(5)}pt  box=$box type=$type  '
          'card=${card.toStringAsFixed(0)}pt  label=${label.toStringAsFixed(1)}pt  '
          'pad=${pad.toStringAsFixed(0)}pt');
      expect(box, greaterThan(1.0));
      expect(type, greaterThan(1.0));
      expect(card, greaterThan(124));
      expect(label, greaterThan(14));
    }
  });

  testWidgets('type is 30% up on the original 1.15/1.25 curve', (tester) async {
    // Locks in the on-device decision so a future "tidy-up" cannot quietly
    // walk it back. See the class doc in responsive_sizing.dart.
    expect(
        await at(tester, 834, (c) => c.typeScale), closeTo(1.15 * 1.30, 0.01));
    expect(
        await at(tester, 1032, (c) => c.typeScale), closeTo(1.25 * 1.30, 0.01));
  });

  testWidgets('My Work card content still fits its box', (tester) async {
    // Type now outruns boxes, so FIT is the guard rail that replaced the old
    // "boxes grow faster than type" rule. Mirrors the real card composition:
    // icon(48) + gap(10) + one line of label(14), inside a 124 card.
    for (final w in [390.0, 834.0, 1032.0, 1440.0]) {
      final card = await at(tester, w, (c) => c.rh(124));
      final icon = await at(tester, w, (c) => c.rr(48));
      final gap = await at(tester, w, (c) => c.rh(10));
      final line = await at(tester, w, (c) => c.rsp(14)) * 1.4; // line height
      final used = icon + gap + line;
      // ignore: avoid_print
      print(
          '${w.toStringAsFixed(0).padLeft(5)}pt  used=${used.toStringAsFixed(0)}'
          ' / card=${card.toStringAsFixed(0)}pt');
      expect(used, lessThan(card),
          reason: 'card content overflows at ${w}pt — give the box more room '
              'or allow a second line, do not shrink the type');
    }
  });
}
