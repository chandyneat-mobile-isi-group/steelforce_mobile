import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// The home hero: photography under an Ironclad overlay, dissolving into the
/// brand wallpaper below it.
///
/// The Brand Guide (Logo Usage, photographic backgrounds) asks for a coloured
/// transparent overlay so type stays legible, which is why the greeting sits
/// on Ironclad Blue rather than black. The top is deep enough for the
/// white-ink wordmark that sits there. The bottom fades to transparent
/// rather than into a flat colour, so the photo melts into the wallpaper with
/// no edge or band — in either theme, since the wallpaper carries its own
/// light/dark colours.
class HomeHeroBackdrop extends StatelessWidget {
  const HomeHeroBackdrop({super.key});

  static const _photo = AppImages.homeHeroPhoto;

  @override
  Widget build(BuildContext context) {
    const navy = AppColors.brandNavy;
    // Opacity mask, same curve the old fade into the canvas used: solid to
    // 62%, a quarter left at 84%, gone at the bottom edge.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x40000000),
          Color(0x00000000),
        ],
        stops: [0.0, 0.62, 0.84, 1.0],
      ).createShader(bounds),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_photo,
              fit: BoxFit.cover, alignment: Alignment.topCenter),
          // Overlay: under the status bar and the white-ink logo, held behind
          // the greeting.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  navy.withValues(alpha: 0.50),
                  navy.withValues(alpha: 0.35),
                  navy.withValues(alpha: 0.55),
                  navy.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.28, 0.55, 0.78],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
