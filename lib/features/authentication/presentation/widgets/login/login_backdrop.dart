import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors_dark.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';

/// The ISI STEEL mark in its full two-tone brand colours
/// (`isi-steel-navy.svg`), straight on the photo — no panel. The light wash
/// at the top of the screen is what keeps the navy legible.
///
/// It gives up its space to the form while the keyboard is open: on a
/// 390x844 phone a 336pt keyboard leaves 508pt of viewport. It carries no
/// action, and the screen it identifies is the one the rep is already
/// looking at, so collapsing it costs nothing and buys back the Sign In
/// button. `BrandLogo` sizes from the artwork's own viewBox, so the keyboard
/// tests measure what a device measures.
class LoginBrand extends StatelessWidget {
  const LoginBrand({super.key});

  /// Space above the mark, inside the safe area.
  static double topGap(BuildContext context) => context.rh(36);

  static double logoWidth(BuildContext context) => context.rr(160);

  /// Where the mark's centre sits, measured from the top of the screen —
  /// what [LoginPhoto] centres its blur on.
  static Offset logoCentre(BuildContext context, double screenWidth) {
    final top = MediaQuery.paddingOf(context).top + topGap(context);
    return Offset(
      screenWidth / 2,
      top + logoWidth(context) / BrandLogo.aspectRatio / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap(context), bottom: context.rh(8)),
      child: Center(
        child: BrandLogo(
          width: logoWidth(context),
          ink: BrandLogoInk.brand,
        ),
      ),
    );
  }
}

/// The ISI building, blurred only in a soft oval behind the brand mark.
///
/// A blurred copy of the photo is laid over the sharp one and masked to an
/// oval that fades out at its rim, so the busy facade right under the mark
/// turns to a calm haze while the rest of the building stays crisp. The blur
/// fades away with the mark when the keyboard takes its space.
class LoginPhoto extends StatelessWidget {
  const LoginPhoto({super.key, required this.showBlur});

  final bool showBlur;

  static const _asset = 'assets/images/isi_building.png';

  static Widget _image() => Image.asset(
        _asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        // Decorative: the screen title says where the user is.
        excludeFromSemantics: true,
      );

  @override
  Widget build(BuildContext context) {
    final centre =
        LoginBrand.logoCentre(context, MediaQuery.sizeOf(context).width);
    // The oval reaches a little past the mark on every side.
    final rx = LoginBrand.logoWidth(context) * 0.85;
    final ry = LoginBrand.logoWidth(context) / BrandLogo.aspectRatio * 1.6;

    return Stack(
      fit: StackFit.expand,
      children: [
        _image(),
        AnimatedOpacity(
          opacity: showBlur ? 1 : 0,
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          child: ClipRect(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              // A radial gradient stretched into an oval around the mark.
              shaderCallback: (_) => ui.Gradient.radial(
                centre,
                rx,
                const [Colors.black, Colors.black, Colors.transparent],
                const [0.0, 0.45, 1.0],
                TileMode.clamp,
                (Matrix4.identity()
                      ..translateByDouble(centre.dx, centre.dy, 0, 1)
                      ..scaleByDouble(1, ry / rx, 1, 1)
                      ..translateByDouble(-centre.dx, -centre.dy, 0, 1))
                    .storage,
              ),
              child: ImageFiltered(
                // Clamped so the blur does not pull transparency in from
                // the screen edges.
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 12,
                  sigmaY: 12,
                  tileMode: TileMode.clamp,
                ),
                child: _image(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white wash over the blurred top, strongest behind the navy mark and
/// gone by the middle of the photo — the mark lifts off the building with no
/// panel behind it. Then the photo fades into the dark base well before the
/// form starts.
class LoginBackdropWash extends StatelessWidget {
  const LoginBackdropWash({super.key});

  static const _base = AppColorsDark.background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.92),
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.0),
            _base.withValues(alpha: 0.65),
            _base,
            _base,
          ],
          stops: const [0.0, 0.12, 0.27, 0.48, 0.68, 1.0],
        ),
      ),
    );
  }
}
