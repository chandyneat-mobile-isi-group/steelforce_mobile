import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';

void main() {
  Future<void> load(WidgetTester tester, Widget mascot) async {
    await tester.pumpWidget(MaterialApp(home: Center(child: mascot)));
    // Asset loading and parsing happen off the fake clock.
    // Retry until the composition has loaded and been laid out.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      final lottie = find.byType(RawLottie);
      if (lottie.evaluate().isNotEmpty &&
          tester.widget<RawLottie>(lottie.first).composition != null) {
        break;
      }
    }
    await tester.pump();
  }

  List<String> shownAssets(WidgetTester tester) => tester
      .widgetList<LottieBuilder>(find.byType(LottieBuilder))
      .map((l) => (l.lottie as AssetLottie).assetName)
      .toList();

  testWidgets('plays the Let\'s Go sticker, not the fallback', (tester) async {
    await load(tester, const CoachMascot(size: 120));

    expect(shownAssets(tester), [CoachMascot.asset]);
    expect(tester.takeException(), isNull);
    // Sized to the sticker's 480 × 600 frame.
    expect(tester.getSize(find.byType(LottieBuilder)), const Size(96, 120));

    // Still animating after the 20-frame intro: the loop has taken over.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('reduced motion holds a still frame', (tester) async {
    await load(tester, const CoachMascot(size: 120, animate: false));

    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('cheer replays the intro, then reports back', (tester) async {
    var cheered = 0;
    await load(
      tester,
      CoachMascot(mood: CoachMood.cheer, onCheerFinish: () => cheered++),
    );

    // The intro is 20 frames at 30 fps ≈ 0.67 s.
    await tester.pump(const Duration(seconds: 1));
    expect(cheered, 1);
  });
}
