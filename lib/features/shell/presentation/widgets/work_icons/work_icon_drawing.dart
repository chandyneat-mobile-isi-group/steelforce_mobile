/// Palette and loop timing shared by the hand-drawn My Work icons — the
/// [WorkIcon] painters and the monthly target's calendar.
library;

import 'package:flutter/animation.dart';
import 'package:steelforce/core/theme/app_colors.dart';

// Brand Guide §07 colours only.
const iconInk = AppColors.brandNavy; // outlines — Ironclad Blue
const iconPaper = Color(0xFFFFFFFF); // fills that must read as "surface"
const iconShade = AppColors.canvas; // soft secondary fill — Foundational White
const iconGo = AppColors.success; // confirmation — Sustainable Green

/// Clamps to 0–1, reading NaN as 0.
double unitClamp(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);

/// Eases a value in over [start]..[end] of the loop.
double loopPhase(double t, double start, double end,
    [Curve curve = Curves.easeInOutCubic]) {
  if (end <= start) return 0;
  return curve.transform(unitClamp((t - start) / (end - start)));
}

/// The whole icon fades down at the very end of the cycle and back up at the
/// start, so a loop never reads as a hard cut.
double loopCycleOpacity(double t) {
  final out = 1 - loopPhase(t, 0.90, 1.00, Curves.easeIn);
  final into = loopPhase(t, 0.00, 0.06, Curves.easeOut);
  return (out * into).clamp(0.0, 1.0);
}
