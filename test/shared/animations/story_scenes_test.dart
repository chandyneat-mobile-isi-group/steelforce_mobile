import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/shared/animations/steel_particle_field.dart';
import 'package:steelforce/features/onboarding/presentation/widgets/story_scenes/story_scenes.dart';

/// The story scenes are drawn almost entirely in `CustomPainter`s, where the
/// failure modes are arithmetic rather than structural: a `t` outside 0–1
/// produces NaN, `computeMetrics().first` throws on an empty path, and a
/// zero-length segment makes `extractPath` return nothing. None of that shows
/// up in static analysis, and all of it crashes onboarding — the first thing a
/// new user ever sees.
///
/// These tests are a crash net plus a set of reference frames. What the
/// animation *looks* like is a human judgement; whether it throws is not.
void main() {
  const primary = Color(0xFF2563EB);
  const slate = Color(0xFF1E293B);
  const success = Color(0xFF2FC767);

  /// `_StepPage` drives each scene from 0 to 0.80 — scenes fade themselves out
  /// past ~0.86 (see `SceneShell`), so the peak is where onboarding parks them.
  const peak = 0.80;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Real fonts, or the goldens render every glyph as a filled box and are
    // useless for judging composition.
    for (final f in [
      'assets/fonts/english/Source_Sans_3/static/SourceSans3-Regular.ttf',
      'assets/fonts/english/Source_Sans_3/static/SourceSans3-Medium.ttf',
      'assets/fonts/english/Source_Sans_3/static/SourceSans3-Bold.ttf',
    ]) {
      final file = File(f);
      if (!file.existsSync()) continue;
      final loader = FontLoader('Source Sans 3')
        ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  Widget frame(Widget scene) => MediaQuery(
        data: const MediaQueryData(size: Size(390, 560)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Source Sans 3'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.white),
                scene,
              ],
            ),
          ),
        ),
      );

  Widget sceneAt(String name, double t) => switch (name) {
        'route' => RouteScene(t: t, line: primary, marker: primary),
        'visit' => VisitScene(t: t, accent: primary, success: success),
        'quotation' => OrderScene(t: t, accent: primary, success: success),
        _ => SuccessScene(t: t, success: success),
      };

  const names = ['route', 'visit', 'quotation', 'success'];

  testWidgets('every scene paints at every point of its animation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final name in names) {
      // Past the peak too: a scene must survive being driven to 1.0 even
      // though onboarding stops short of it.
      for (var i = 0; i <= 40; i++) {
        final t = i / 40;
        await tester.pumpWidget(frame(sceneAt(name, t)));
        expect(tester.takeException(), isNull, reason: '$name threw at t=$t');
      }
    }
  });

  testWidgets('the particle field paints across its whole range',
      (tester) async {
    for (var i = 0; i <= 30; i++) {
      final p = i / 30;
      await tester.pumpWidget(frame(SteelParticleField(
        progress: p,
        steel: slate,
        highlight: primary,
        convergeFrom: 0.22,
      )));
      expect(tester.takeException(), isNull, reason: 'field threw at p=$p');
    }
  });

  for (final name in names) {
    testWidgets('golden_$name', (tester) async {
      tester.view.physicalSize = const Size(390, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(frame(sceneAt(name, peak)));
      await expectLater(
        find.byType(Stack).first,
        matchesGoldenFile('frames/$name.png'),
      );
    });
  }
}
