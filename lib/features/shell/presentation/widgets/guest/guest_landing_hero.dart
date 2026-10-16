import 'package:flutter/material.dart';

/// The guest landing illustration — a field rep with the app, between the
/// city and the steel yard.
///
/// The artwork has a near-white background, so its edges are faded out
/// rather than ending in a hard rectangle; that lets it sit on the page's own
/// background instead of looking pasted on.
class GuestLandingHero extends StatelessWidget {
  const GuestLandingHero({super.key, required this.maxHeight});

  static const asset = 'assets/images/guest_landing_hero.jpeg';

  /// Width ÷ height of [asset].
  static const aspectRatio = 850 / 540;

  /// The tallest the illustration may be. It shrinks to this on short
  /// screens so the sign-in button stays above the fold.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.08, 0.86, 1.0],
          ).createShader(rect),
          // …and the sides, so it blends into the page at the screen edge.
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.05, 0.95, 1.0],
            ).createShader(rect),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              // Decorative: the tagline below says what the picture shows.
              excludeFromSemantics: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
