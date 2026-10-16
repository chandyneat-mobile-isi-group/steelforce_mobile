import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';

/// The asset each `SvgPicture` in the tree was pointed at, front to back.
List<String> _assets(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .map((w) => (w.bytesLoader as SvgAssetLoader).assetName)
    .toList();

// The default mark, SteelForce: the full-colour logo is both the dark and the
// brand ink; the light ink recolours only its wordmark.
const _light = 'assets/logos/steelforce/steelforce_logo_light.svg';
const _dark = 'assets/logos/steelforce/steelforce_logo.svg';
const _brand = _dark;

// ISI Steel, kept for the documents ISI Steel issues.
const _isiLight = 'assets/logos/isi-steel-light.svg';
const _isiDark = 'assets/logos/isi-steel-dark.svg';
const _isiBrand = 'assets/logos/isi-steel-navy.svg';

Future<void> _pump(
  WidgetTester tester,
  Widget logo, {
  Brightness brightness = Brightness.light,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.dark('Inter')
          : AppTheme.light('Inter'),
      home: Scaffold(body: Center(child: logo)),
    ));

void main() {
  group('auto ink follows the surface', () {
    // The regression this widget exists to prevent: one hardcoded asset drawn
    // on both a white language picker and a near-black glass panel, where the
    // dark mark does not merely lose contrast — it disappears.
    testWidgets('light theme gets the dark mark', (tester) async {
      await _pump(tester, const BrandLogo(width: 200));

      expect(_assets(tester), [_dark]);
    });

    testWidgets('dark theme gets the light mark', (tester) async {
      await _pump(tester, const BrandLogo(width: 200),
          brightness: Brightness.dark);

      expect(_assets(tester), [_light]);
    });
  });

  group('explicit ink overrides the theme', () {
    // Needed because two surfaces in this app do not follow the theme at all:
    // the login glass panel and the home app bar both sit on photography and
    // are dark in *both* themes.
    testWidgets('light ink on a light theme', (tester) async {
      await _pump(tester, const BrandLogo(width: 200, ink: BrandLogoInk.light));

      expect(_assets(tester), [_light],
          reason: 'a dark photo under a light theme still needs light ink');
    });

    testWidgets('dark ink on a dark theme', (tester) async {
      await _pump(tester, const BrandLogo(width: 200, ink: BrandLogoInk.dark),
          brightness: Brightness.dark);

      expect(_assets(tester), [_dark]);
    });

    testWidgets('brand ink is the two-tone export', (tester) async {
      await _pump(tester, const BrandLogo(width: 200, ink: BrandLogoInk.brand));

      expect(_assets(tester), [_brand]);
    });
  });

  group('a plate becomes the surface', () {
    // Resolving against the theme here would be wrong in the one case a plate
    // is for: a dark plate over bright photography sits inside a *light* theme,
    // so the theme would pick dark ink on a dark panel.
    testWidgets('a dark plate flips auto to light ink', (tester) async {
      await _pump(
        tester,
        const BrandLogo(width: 200, plate: Color(0xFF011E41)),
      );

      expect(_assets(tester), [_light]);
    });

    testWidgets('a light plate keeps dark ink under a dark theme',
        (tester) async {
      await _pump(
        tester,
        const BrandLogo(width: 200, plate: Colors.white),
        brightness: Brightness.dark,
      );

      expect(_assets(tester), [_dark]);
    });

    testWidgets('explicit ink still wins over the plate', (tester) async {
      await _pump(
        tester,
        const BrandLogo(
          width: 200,
          plate: Colors.white,
          ink: BrandLogoInk.light,
        ),
      );

      expect(_assets(tester), [_light],
          reason: 'the caller stated the ink; the plate must not second-guess');
    });

    testWidgets('the plate paints a rounded, elevated panel', (tester) async {
      await _pump(
          tester, const BrandLogo(width: 200, plate: Color(0xFF011E41)));

      final decoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == const Color(0xFF011E41));

      expect(decoration.borderRadius, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('no plate paints no panel', (tester) async {
      await _pump(tester, const BrandLogo(width: 200));

      final plates = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow?.isNotEmpty ?? false);

      expect(plates, isEmpty);
    });
  });

  group('shadow', () {
    testWidgets('draws a second, tinted copy behind the mark', (tester) async {
      await _pump(tester, const BrandLogo(width: 200, shadow: true));

      final pictures =
          tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();

      expect(pictures, hasLength(2), reason: 'silhouette + mark');
      // The silhouette is flattened to one colour; the mark is untouched.
      expect(pictures.first.colorFilter, isNotNull);
      expect(pictures.last.colorFilter, isNull);
      expect(_assets(tester), [_dark, _dark],
          reason: 'the silhouette is the same artwork, not a different export');
    });

    testWidgets('blurs the silhouette rather than boxing the widget',
        (tester) async {
      // A `BoxShadow` would trace the bounding box and draw a grey rectangle
      // around a transparent logo. The shape-following version is an
      // `ImageFiltered` blur over the artwork itself.
      await _pump(tester, const BrandLogo(width: 200, shadow: true));

      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('off by default', (tester) async {
      await _pump(tester, const BrandLogo(width: 200));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('announces the mark once, not twice', (tester) async {
      // Two copies of one logo would be read out twice by a screen reader.
      await _pump(tester, const BrandLogo(width: 200, shadow: true));

      expect(
        find.bySemanticsLabel('SteelForce'),
        findsOneWidget,
      );
    });
  });

  group('the ISI Steel mark', () {
    testWidgets('keeps its three inks', (tester) async {
      await _pump(
          tester, const BrandLogo(width: 200, mark: BrandMark.isiSteel));
      expect(_assets(tester), [_isiDark]);

      await _pump(
          tester,
          const BrandLogo(
              width: 200, mark: BrandMark.isiSteel, ink: BrandLogoInk.light));
      expect(_assets(tester), [_isiLight]);

      await _pump(
          tester,
          const BrandLogo(
              width: 200, mark: BrandMark.isiSteel, ink: BrandLogoInk.brand));
      expect(_assets(tester), [_isiBrand]);
    });

    testWidgets('is announced as ISI Steel and sized from its own artwork',
        (tester) async {
      await _pump(
          tester, const BrandLogo(height: 40, mark: BrandMark.isiSteel));
      expect(find.bySemanticsLabel('ISI Steel'), findsOneWidget);
      expect(tester.getSize(find.byType(SvgPicture)).width,
          closeTo(40 * BrandLogo.isiSteelAspectRatio, 0.01));
    });
  });

  group('the artwork itself', () {
    // `flutter_svg` does not implement `<style>` or CSS classes — it logs
    // `unhandled element <style/>` and carries on, leaving every path with the
    // SVG default fill, which is **black**. The navy export arrived straight
    // from Illustrator in exactly that shape, so the two-tone brand mark
    // rendered as a flat black slab and no amount of ink selection or shadow
    // could have fixed it. An Illustrator re-export would reintroduce it
    // silently, which is why this is asserted rather than trusted.
    for (final asset in [_dark, _light, _isiBrand, _isiLight, _isiDark]) {
      test('$asset states its colours as attributes, not CSS', () async {
        final source = await File(asset).readAsString();

        expect(source, isNot(contains('<style')),
            reason: 'flutter_svg ignores <style>, dropping every fill');
        expect(source, isNot(contains('class="')),
            reason: 'class-based fills resolve to nothing at render time');
        expect(source, contains('fill="'),
            reason: 'the colours have to survive as attributes');
      });
    }

    test('the ISI Steel brand export keeps both brand colours', () async {
      final source = await File(_isiBrand).readAsString();

      expect(source, contains('#011E41'), reason: 'navy seal');
      expect(source, contains('#004A98'), reason: 'blue wordmark');
    });

    test('the SteelForce light ink recolours only the wordmark', () async {
      final full = await File(_dark).readAsString();
      final light = await File(_light).readAsString();

      // "Steel" navy and "Force" blue on the full-colour logo…
      expect(full, contains('#011A45'));
      expect(full, contains('#013DB2'));
      // …and neither survives on the light ink, which would vanish on a
      // dark surface. The tile's own gradient is untouched.
      expect(light, isNot(contains('#011A45')));
      expect(light, isNot(contains('#013DB2')));
      expect(light, contains('#021C50'), reason: 'tile gradient kept');
    });
  });

  group('sizing', () {
    testWidgets('a width derives the height from the artwork', (tester) async {
      const width = 100 * BrandLogo.aspectRatio;
      await _pump(tester, const BrandLogo(width: width));

      final box = tester.getSize(find.byType(SvgPicture));

      expect(box.width, closeTo(width, 0.01));
      expect(box.height, closeTo(100, 0.01));
    });

    testWidgets('a height derives the width', (tester) async {
      await _pump(tester, const BrandLogo(height: 100));

      final box = tester.getSize(find.byType(SvgPicture));

      expect(box.width, closeTo(100 * BrandLogo.aspectRatio, 0.01));
    });

    testWidgets('neither width nor height is a programming error',
        (tester) async {
      // The artwork is 2.75:1 and was previously forced into boxes it does not
      // fit with `BoxFit.cover`, which cropped the wordmark. Sizing against one
      // axis is the fix, so refusing both is deliberate.
      expect(() => BrandLogo(width: null, height: null), throwsAssertionError);
    });
  });
}
