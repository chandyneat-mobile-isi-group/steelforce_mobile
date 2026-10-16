import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:steelforce/core/localization/localization_services.dart';

/// Scene 6 — the mark the whole story has been assembling.
///
/// The particle field converges on this widget's centre (see
/// `SteelParticleField`), so the reveal is timed to *finish* the gather rather
/// than start after it: the logo is already at 60% opacity while the last motes
/// are still arriving. Waiting for the field to settle first would read as two
/// events instead of one.
///
/// Uses the real brand assets — the SteelForce icon, then its wordmark. The
/// brief is explicit that the logo is not to be redesigned, so nothing here
/// draws it — this only scales, lights and holds it.
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
                boxShadow: [
                  BoxShadow(
                    // Restrained on white, where a wide bloom turns grey.
                    color: highlight.withValues(
                        alpha: 0.16 * appear * (1 - settle)),
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
                    // White at low alpha over a navy mark on a white page:
                    // the band lifts the logo rather than washing it out. A
                    // darker sweep would read as a shadow crossing it.
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: sweep > 0 ? 0.42 : 0.0),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 0.5, 0.65],
                  ).createShader(rect);
                },
                child: SvgPicture.asset(
                  'assets/logos/steelforce/steelforce_icon.svg',
                  width: 124,
                  height: 124,
                  // Decorative: the wordmark below carries the label.
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: _u((t - 0.45) / 0.35),
              child: SvgPicture.asset(
                'assets/logos/steelforce/steelforce_wordmark.svg',
                width: 230,
                semanticsLabel: 'splash.brand'.tr,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _u(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
