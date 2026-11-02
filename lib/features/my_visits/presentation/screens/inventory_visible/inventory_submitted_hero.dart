import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';

/// The SteelForce mascot acting out the result, on a flat brand-tint stage.
///
/// The sticker tells the whole story without words, so it reads the same in
/// Khmer and English: the mascot snaps a photo on its phone, the photo flies
/// up into its speech bubble, an upload bar fills, a green check lands and
/// the mascot hops. It then plays one calm idle pass and holds — a
/// confirmation screen is read, not watched. Reduced motion shows the held,
/// finished frame (photo in the bubble, check visible).
class InventorySubmittedHero extends StatelessWidget {
  const InventorySubmittedHero(
      {super.key, required this.size, required this.semanticLabel});

  /// Height of the hero box; the mascot fills it, the stage sits behind.
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final stage = size * 0.62;

    return Semantics(
      // One announcement for the whole picture; the mascot itself is
      // decorative and a rep should hear the result, not "animation".
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Stage behind the robot's body, low enough that its shadow sits
            // on it and clear of the speech bubble at upper-right.
            Align(
              alignment: const Alignment(-0.1, 0.55),
              child: Container(
                width: stage,
                height: stage,
                decoration: BoxDecoration(
                  color: colors.surfaceStrong,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            CoachMascot(
              animationAsset: CoachMascot.inventorySuccessAsset,
              mood: CoachMood.cheer,
              size: size,
              loop: false,
              animate: !reduceMotion,
            ),
          ],
        ),
      ),
    );
  }
}
