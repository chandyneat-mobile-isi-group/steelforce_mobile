import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Which brand the logo shows.
enum BrandMark {
  /// The app: the SteelForce "S" tile with its wordmark. Every in-app use.
  steelForce,

  /// The company: the ISI Steel seal and wordmark. For documents ISI Steel
  /// issues to customers — the quotation and its preview.
  isiSteel,
}

/// Which ink the wordmark is drawn in.
///
/// The artwork ships as separate exports rather than one tinted asset because
/// both marks are **multi-tone** (ISI Steel: navy seal, blue wordmark;
/// SteelForce: a full-colour tile, navy "Steel", blue "Force") and a single
/// `colorFilter` would flatten that into one colour.
enum BrandLogoInk {
  /// Resolved from the surface the mark is drawn on: dark ink on a light
  /// surface, light ink on a dark one.
  ///
  /// The surface is [ThemeData.brightness], or — when [BrandLogo.plate] is set
  /// — the plate colour, because a plate *becomes* the surface. Correct for
  /// anything sitting on a themed background.
  auto,

  /// Near-white `#DCE3EB`. For dark surfaces that do **not** follow the theme —
  /// photography, scrims, glass panels — where `auto` would read the light
  /// theme and pick dark ink that vanishes.
  light,

  /// Navy `#011E41`. For light surfaces that do not follow the theme.
  dark,

  /// The full two-tone brand mark. Only legible on white or near-white; it is
  /// the print/document version, not a UI ink.
  brand,
}

/// A brand logo — SteelForce by default, ISI Steel with
/// [BrandMark.isiSteel] — sized from the artwork.
///
/// The SteelForce light ink recolours only the wordmark (white "Steel", light
/// blue "Force"); its tile keeps its own navy, which reads on any surface.
///
/// ## Contrast is the whole job of this widget
///
/// The mark is drawn over four very different surfaces in this app — a white
/// language picker, a themed quotation card, the home app bar over photography,
/// and a 15%-white glass panel over `isi_building.png` under a black gradient.
/// One fixed ink cannot read on all four, and picking the wrong one does not
/// degrade gracefully: `#011E41` on near-black is invisible, not merely low
/// contrast. So the ink is chosen per surface ([BrandLogoInk]) and two further
/// contrast aids are available for imagery, where no ink is reliably safe:
///
///  * [shadow] — a **shape-following** drop shadow. Lifts the mark off a busy
///    photo while leaving it transparent.
///  * [plate] — an opaque rounded panel behind the mark. The guaranteed option:
///    it replaces the surface instead of fighting it, and `auto` then resolves
///    the ink against the plate.
///
/// Both are off by default, so a caller that does nothing gets today's look
/// with the ink corrected.
///
/// ## Why the shadow is not a `BoxShadow`
///
/// A `BoxShadow` on a `DecoratedBox` traces the widget's **bounding box**, so
/// over photography it draws a soft grey rectangle around a transparent logo —
/// visibly a mistake rather than a subtle lift. [shadow] instead re-renders the
/// same artwork as a solid silhouette, blurs it, and offsets it behind the
/// mark, which follows the glyphs.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.ink = BrandLogoInk.auto,
    this.shadow = false,
    this.plate,
    this.mark = BrandMark.steelForce,
    String? semanticsLabel,
  })  : semanticsLabel = semanticsLabel ??
            (mark == BrandMark.steelForce ? 'SteelForce' : 'ISI Steel'),
        assert(
          width != null || height != null,
          'BrandLogo needs a width or a height to size against.',
        );

  /// Target width. The height follows from the artwork's aspect ratio.
  final double? width;

  /// Target height. Used when [width] is null.
  final double? height;

  /// Which ink to draw. See [BrandLogoInk].
  final BrandLogoInk ink;

  /// Adds a shape-following drop shadow.
  ///
  /// For the mark over photography or any surface whose value is not known at
  /// build time. Costs a second rasterisation of the same asset, so it is opt-in
  /// rather than always-on.
  final bool shadow;

  /// Draws the mark on a rounded panel of this colour instead of directly on
  /// the surface.
  ///
  /// Use `context.appColors.card` for a theme-following panel, or a translucent
  /// white/navy for a scrim over imagery. When set, [BrandLogoInk.auto]
  /// resolves against **this** colour rather than the theme, because the plate
  /// is what the mark is now sitting on.
  final Color? plate;

  /// Which brand to draw.
  final BrandMark mark;

  final String semanticsLabel;

  /// Width ÷ height of the SteelForce horizontal logo
  /// (`viewBox="69.71 103.35 1131.54 402.81"`, shared by both inks).
  static const aspectRatio = 1131.54 / 402.81;

  /// Width ÷ height of the ISI Steel exports. `isi-steel-navy.svg` states
  /// `viewBox="0 0 1101.09 400"` and the two mono exports
  /// `viewBox="409.45 340 1101.1 400"` — the same ratio to five decimal
  /// places, so one constant covers all three.
  static const isiSteelAspectRatio = 1101.1 / 400.0;

  double get _ratio =>
      mark == BrandMark.steelForce ? aspectRatio : isiSteelAspectRatio;

  // ISI Steel.
  static const _lightInkAsset = 'assets/logos/isi-steel-light.svg';
  static const _darkInkAsset = 'assets/logos/isi-steel-dark.svg';
  static const _brandInkAsset = 'assets/logos/isi-steel-navy.svg';

  // SteelForce. The full-colour logo is both the dark and the brand ink.
  static const _steelForceAsset = 'assets/logos/steelforce/steelforce_logo.svg';
  static const _steelForceLightAsset =
      'assets/logos/steelforce/steelforce_logo_light.svg';

  @override
  Widget build(BuildContext context) {
    final w = width ?? height! * _ratio;
    final h = height ?? width! / _ratio;

    final asset = _resolveAsset(context);

    // Padding and radius scale with the mark so a 40pt logo and a 200pt logo
    // both look deliberate rather than one being swallowed by its own panel.
    final pad = h * 0.16;
    final radius = h * 0.34;

    Widget mark = SizedBox(
      width: w,
      height: h,
      child: shadow
          ? _withShadow(context, asset: asset, width: w, height: h)
          : SvgPicture.asset(asset, width: w, height: h, fit: BoxFit.contain),
    );

    final plateColour = plate;
    if (plateColour != null) {
      mark = DecoratedBox(
        decoration: BoxDecoration(
          color: plateColour,
          borderRadius: BorderRadius.circular(radius),
          // The panel itself is elevated with the app's card shadow so it reads
          // as a surface rather than a painted rectangle.
          boxShadow: context.appColors.cardShadow,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.7),
          child: mark,
        ),
      );
    }

    return Semantics(
      label: semanticsLabel,
      image: true,
      child: mark,
    );
  }

  /// The silhouette copy, blurred and offset, then the mark on top.
  Widget _withShadow(
    BuildContext context, {
    required String asset,
    required double width,
    required double height,
  }) {
    // Scaled to the mark: a fixed 4pt blur is a smudge under a 200pt logo and a
    // black bar under a 40pt one.
    final blur = (height * 0.10).clamp(1.5, 10.0);
    final dy = (height * 0.05).clamp(0.5, 4.0);

    // The shadow is always dark, including under light ink — a light-on-light
    // glow reads as a rendering fault, while a dark shadow under a near-white
    // mark is what separates it from a bright patch of photography.
    final shadowColour = context.appColors.shadowColor.withValues(alpha: 0.45);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Excluded from semantics: the same mark announced twice is noise, and
        // the real one below already carries the label.
        ExcludeSemantics(
          child: Transform.translate(
            offset: Offset(0, dy),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: SvgPicture.asset(
                asset,
                width: width,
                height: height,
                fit: BoxFit.contain,
                // Flattens the artwork to one solid colour so the blur produces
                // a silhouette rather than a smeared copy of the logo.
                colorFilter: ColorFilter.mode(shadowColour, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        SvgPicture.asset(asset,
            width: width, height: height, fit: BoxFit.contain),
      ],
    );
  }

  String _resolveAsset(BuildContext context) {
    final light = _wantsLightInk(context);
    return switch (mark) {
      BrandMark.steelForce => light ? _steelForceLightAsset : _steelForceAsset,
      BrandMark.isiSteel => ink == BrandLogoInk.brand
          ? _brandInkAsset
          : (light ? _lightInkAsset : _darkInkAsset),
    };
  }

  bool _wantsLightInk(BuildContext context) => switch (ink) {
        BrandLogoInk.light => true,
        BrandLogoInk.dark || BrandLogoInk.brand => false,
        // A plate is the surface once it exists, so it — not the theme —
        // decides the ink. `estimateBrightnessForColor` is the same helper
        // Flutter's own components use to pick foreground ink, and it accounts
        // for the plate being translucent only insofar as its alpha is baked
        // into the colour; a heavily transparent plate should state its ink.
        BrandLogoInk.auto => switch (plate) {
            final Color c =>
              ThemeData.estimateBrightnessForColor(c) == Brightness.dark,
            null => Theme.of(context).brightness == Brightness.dark,
          },
      };
}
