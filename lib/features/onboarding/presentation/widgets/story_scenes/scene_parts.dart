/// Shared building blocks for the splash story's scenes: palette, entry and
/// exit, the card surface, text, and the 0–1 clamp every scene uses.
///
/// Every scene is a pure function of a single `t` in 0–1 supplied by
/// `SplashTimeline`. None owns a controller, none owns state, and none knows
/// what comes before or after it — which is what lets the story be re-timed by
/// editing one interval table instead of renegotiating seven widgets.
///
/// The palette is light throughout: the story plays on white, so every surface
/// here is an opaque card with a real border, not a translucent "glass" panel.
/// Frosted panels need something dark behind them to read at all; on white they
/// disappear.
library;

import 'package:flutter/material.dart';

const sceneInk = Color(0xFF1E293B); // slate — primary text
const sceneMuted = Color(0xFF64748B); // secondary text
const sceneHairline = Color(0xFFE2E8F0); // borders, road casing
const sceneBlockFill = Color(0xFFEEF2F6); // map blocks

/// Wraps a scene in its entry and exit.
///
/// Scenes rise slightly, fade in, hold, then fade and sink as the next takes
/// over. The vertical travel is deliberately small (10px): the tell of the
/// Apple-like motion the brief asks for is that things move *less* than you
/// expect, not more.
class SceneShell extends StatelessWidget {
  const SceneShell({super.key, required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Quick in, long hold, quick out. With sequential scene windows the hold is
    // the majority of the beat — that hold is what "one at a time" means.
    final fadeIn = Curves.easeOut.transform(sceneUnit(t / 0.16));
    final fadeOut = 1 - Curves.easeIn.transform(sceneUnit((t - 0.86) / 0.14));
    final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
    if (opacity <= 0.01) return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, (1 - fadeIn) * 10 - (1 - fadeOut) * 10),
          child: child,
        ),
      ),
    );
  }
}

/// The card style every scene uses.
///
/// One card across four scenes is what makes the route card, the visit card and
/// the order rows read as the *same application* rather than three unrelated
/// illustrations.
class SceneCard extends StatelessWidget {
  const SceneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sceneHairline),
        boxShadow: [
          BoxShadow(
            color: sceneInk.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Text helper for the scenes.
///
/// Deliberately not themed: these are illustrations that always play on the
/// white story backdrop, so their colours must not follow the app's light/dark
/// setting — a dark-mode swap here would render them invisible.
class SceneText extends StatelessWidget {
  const SceneText(
    this.text, {
    super.key,
    required this.size,
    required this.color,
    this.weight = FontWeight.w600,
    this.align = TextAlign.center,
  });

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0.5,
        height: 1.2,
      ),
    );
  }
}

/// Clamps to 0–1, reading NaN as 0.
double sceneUnit(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
