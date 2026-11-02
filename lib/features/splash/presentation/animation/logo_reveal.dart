import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// Scene 6 — the mark the whole story has been assembling.
///
/// The particle field converges on this widget's centre (see
/// `SteelParticleField`), so the reveal is timed to *finish* the gather rather
/// than start after it: the logo is already at 60% opacity while the last motes
/// are still arriving. Waiting for the field to settle first would read as two
/// events instead of one.
///
/// Uses the real brand asset. The brief is explicit that the logo is not to be
/// redesigned, so nothing here draws it — this only scales, lights and holds it.
class LogoReveal extends StatelessWidget {
  const LogoReveal({
    super.key,
    required this.t,
    required this.settle,
    required this.highlight,
  });

  /// Progress of the reveal window, 0–1.
  final double t;

  /// Progress of the hand-off window, 0–1. Drives the gentle scale-down as the
  /// splash gives way to the app, so the logo shrinks *into* the home screen
  /// rather than cutting away from it.
  final double settle;

  final Color highlight;

  /// Side of the app-icon tile, in logical pixels.
  static const double _tile = 132;

  /// The artwork's corner radius as a fraction of its side
  /// (`rx="229.4"` on a 1024 canvas).
  static const double _tileCorner = 229.4 / 1024;

  @override
  Widget build(BuildContext context) {
    final appear = Curves.easeOutCubic.transform(_u(t / 0.55));
    if (appear <= 0.01) return const SizedBox.shrink();

    // Overshoot slightly, then relax — the spring the brief asks for, kept
    // small enough to read as confident rather than bouncy.
    final pop = Curves.easeOutBack.transform(_u(t / 0.62));
    final scale = (0.86 + 0.14 * pop) * (1 - 0.10 * settle);

    // The sweep crosses once, on arrival. Repeating it would turn a highlight
    // into a shimmer effect, which is exactly the "cheap template" look the
    // brief rules out.
    final sweep = _u((t - 0.42) / 0.40);

    return Opacity(
      opacity: appear * (1 - 0.25 * settle),
      child: Transform.scale(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soft glow behind the mark, strongest as it lands.
            Container(
              decoration: BoxDecoration(
                // Follows the tile's corner so the glow is a rounded halo,
                // not a square one.
                borderRadius: BorderRadius.circular(_tile * _tileCorner),
                boxShadow: [
                  BoxShadow(
                    // A light halo lifting the tile off the blue backdrop.
                    color: highlight.withValues(
                        alpha: 0.22 * appear * (1 - settle)),
                    blurRadius: 42,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (rect) {
                  // A narrow white band travelling left→right across the mark.
                  final x = -1.0 + 3.0 * sweep;
                  return LinearGradient(
                    begin: Alignment(x - 0.45, -1),
                    end: Alignment(x + 0.45, 1),
                    // White at low alpha: the band lifts the logo rather
                    // than washing it out. A darker sweep would read as a
                    // shadow crossing it.
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: sweep > 0 ? 0.42 : 0.0),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 0.5, 0.65],
                  ).createShader(rect);
                },
                // The SteelForce app-icon tile in its light version — white,
                // so it stands off the navy backdrop where the blue launcher
                // tile would sink into it. The name is the text below it.
                child: Image.asset(
                  AppLogos.steelForceAppIconWhite,
                  width: _tile,
                  height: _tile,
                  fit: BoxFit.contain,
                  // A missing asset must not stall the boot path. Reserve the
                  // space so the column below does not jump, and say so in
                  // debug — the silent empty Container this replaced is how a
                  // never-bundled asset once looked like "the image is broken".
                  errorBuilder: (context, error, stack) {
                    assert(() {
                      debugPrint('[splash] logo failed to load: $error');
                      return true;
                    }());
                    return const SizedBox(width: _tile, height: _tile);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: _u((t - 0.45) / 0.35),
              child: Text(
                // Keyed, not literal. `splash.brand` resolves to "SteelForce"
                // in both bundles; brand names are not translated, but keying
                // them makes a rebrand a bundle edit rather than a code hunt.
                'splash.brand'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _u(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
