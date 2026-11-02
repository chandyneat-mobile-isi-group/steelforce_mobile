import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/brand_pattern_background.dart';

/// Which SteelForce wallpaper to draw. Both are white under the brand
/// chevron (`paintBrandChevrons`, shared with the sign-in backdrop); they
/// differ only in how faint the chevron is — each has its own colour tokens,
/// light and dark.
enum BrandWallpaperStyle {
  /// Home and the work tabs: the chevron at its fuller strength.
  vivid,

  /// Text-heavy screens (profile): fainter, so long text stays the focus.
  subtle,
}

/// The SteelForce wallpaper: a white vertical blend under the brand chevron,
/// in one of two
/// [BrandWallpaperStyle]s — [BrandWallpaperStyle.vivid] behind the home
/// screen, [BrandWallpaperStyle.subtle] behind the profile.
///
/// Theme-aware: the colours come from [AppThemeColors] (`wallpaper*` for
/// vivid, `wallpaperSubtle*` for subtle), so it follows light and dark mode
/// (and their transition) with no extra wiring. Pass [top], [bottom] or
/// [lineColor] only to override one screen.
///
/// Drawn rather than bundled as an image, so it is sharp at every density and
/// fits any aspect ratio without stretching the chevron. Fills its parent: use
/// it as `Positioned.fill` under a screen's content, or pass [child]. The
/// In the default expanding mode, the pattern is painted into its own layer
/// ([RepaintBoundary]), so scrolling or animating content above it never
/// repaints it. [fitToChild] instead paints behind a naturally sized child.
///
/// Not to be confused with `BrandPatternBackground`: the flat backdrop with
/// hairline chevrons used by splash and sign-in.
class BrandWallpaperBackground extends StatelessWidget {
  const BrandWallpaperBackground({
    super.key,
    this.style = BrandWallpaperStyle.vivid,
    this.top,
    this.bottom,
    this.lineColor,
    this.fitToChild = false,
    this.child,
  });

  final BrandWallpaperStyle style;
  final Color? top;
  final Color? bottom;

  /// The chevron. Keep it faint: it is texture, and content reads over it.
  final Color? lineColor;

  /// Paints behind [child] at the child's natural size instead of expanding
  /// the background to fill its parent's constraints.
  final bool fitToChild;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final subtle = style == BrandWallpaperStyle.subtle;
    final pattern = RepaintBoundary(
      child: CustomPaint(
        painter: _WallpaperPainter(
          style: style,
          top:
              top ?? (subtle ? colors.wallpaperSubtleTop : colors.wallpaperTop),
          bottom: bottom ??
              (subtle ? colors.wallpaperSubtleBottom : colors.wallpaperBottom),
          // A screen that paints its own colours (a red danger header) gets
          // a faint white chevron: the navy one is tuned for white.
          lineColor: lineColor ??
              (top != null || bottom != null
                  ? const Color(0x1FFFFFFF)
                  : subtle
                      ? colors.wallpaperSubtleLine
                      : colors.wallpaperLine),
        ),
        child: fitToChild && child != null ? child : const SizedBox.expand(),
      ),
    );
    return child == null || fitToChild
        ? pattern
        : Stack(fit: StackFit.expand, children: [pattern, child!]);
  }
}

/// Places the subtle SteelForce wallpaper behind screen content while leaving
/// each screen's app bar and system-bar styling in control of its own colors.
class BrandWallpaperBody extends StatelessWidget {
  const BrandWallpaperBody({
    super.key,
    required this.child,
    this.style = BrandWallpaperStyle.subtle,
  });

  final Widget child;

  /// Subtle by default; the work tabs (Depots, Visits) and their screens use
  /// vivid to match Home.
  final BrandWallpaperStyle style;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          BrandWallpaperBackground(style: style),
          child,
        ],
      );
}

class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter({
    required this.style,
    required this.top,
    required this.bottom,
    required this.lineColor,
  });

  final BrandWallpaperStyle style;
  final Color top;
  final Color bottom;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(bounds),
    );
    paintBrandChevrons(canvas, size, lineColor);
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.style != style ||
      old.top != top ||
      old.bottom != bottom ||
      old.lineColor != lineColor;
}
