import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/shared/animations/steelforce_success_animation.dart';

/// The celebration is drawn in a `CustomPainter`, where the failure modes are
/// arithmetic: a NaN from a zero-length window, an empty path handed to
/// `computeMetrics().first`, an alpha outside 0–1. None of it shows up in
/// analysis, and all of it crashes the screen that tells a rep their work was
/// saved — the worst possible moment to fail.
void main() {
  Future<void> run(WidgetTester tester, {required bool reduceMotion}) async {
    tester.view.physicalSize = const Size(240, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Scaffold(
          body: Center(
            child: SteelForceSuccessAnimation(
                size: 200, primaryColor: Color(0xFF2563EB)),
          ),
        ),
      ),
    ));

    // Past the 2200ms arrival and into the idle breath, a frame at a time.
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull,
          reason: 'threw at ${i * 20}ms (reduceMotion: $reduceMotion)');
    }
  }

  testWidgets('paints every frame of the arrival and the idle after it',
      (tester) async => run(tester, reduceMotion: false));

  testWidgets('reduce-motion holds the settled frame without throwing',
      (tester) async => run(tester, reduceMotion: true));

  testWidgets('the idle breath keeps running after the burst finishes',
      (tester) async {
    // The burst controller completes; the breath one repeats. If the widget
    // ever stopped scheduling frames the mark would freeze mid-glow.
    tester.view.physicalSize = const Size(240, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SteelForceSuccessAnimation(
              size: 200, primaryColor: Color(0xFF2563EB)),
        ),
      ),
    ));
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    // Still animating well past the 2200ms arrival — pumpAndSettle would hang
    // here, which is itself the proof, so it is deliberately not called.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
