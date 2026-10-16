import 'package:flutter/material.dart';

/// The blue-and-gold sweep with steel beams along the bottom edge of the
/// guest landing. Purely decorative; drawn behind the content.
class GuestLandingFooter extends StatelessWidget {
  const GuestLandingFooter({super.key});

  static const asset = 'assets/images/guest_landing_footer.jpg';

  /// Width ÷ height of [asset].
  static const aspectRatio = 850 / 138;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        // Fades in from the top, so the strip rises out of the page instead
        // of starting at a hard edge.
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
          stops: [0.0, 0.35],
        ).createShader(rect),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
