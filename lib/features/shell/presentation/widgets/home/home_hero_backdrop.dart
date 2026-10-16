import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The home hero: photography under an Ironclad overlay, dissolving into the
/// page canvas at the bottom.
///
/// The Brand Guide (Logo Usage, photographic backgrounds) asks for a coloured transparent
/// overlay so type stays legible, which is why the greeting sits on Ironclad
/// Blue rather than black. The top is kept light: the navy wordmark sits there
/// on its own white glow. The bottom fades into
/// [AppThemeColors.canvas] — Foundational White in light mode, the dark canvas
/// in dark mode — so the photo has no edge against the page.
class HomeHeroBackdrop extends StatelessWidget {
  const HomeHeroBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final canvas = context.appColors.canvas;
    const navy = AppColors.brandNavy;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/isi_main_app_bar_bg.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        // Overlay: light under the status bar and logo, held behind the
        // greeting.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                navy.withValues(alpha: 0.25),
                navy.withValues(alpha: 0.15),
                navy.withValues(alpha: 0.55),
                navy.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.28, 0.55, 0.78],
            ),
          ),
        ),
        // The fade into the page.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                canvas.withValues(alpha: 0.0),
                canvas.withValues(alpha: 0.75),
                canvas,
              ],
              stops: const [0.62, 0.84, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
