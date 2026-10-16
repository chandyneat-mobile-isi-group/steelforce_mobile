import 'package:flutter/animation.dart';

/// Central motion tokens for the dashboard (and the wider app).
///
/// Keeping durations and curves in one place guarantees every entrance,
/// press, and transition feels like it belongs to the same design system —
/// the way Linear / Stripe / Arc keep their motion tightly coordinated.
abstract final class AppDurations {
  const AppDurations._();

  /// Micro feedback (highlight, ripple settle, shadow lift).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard implicit animation (colour, size, badge swap).
  static const Duration medium = Duration(milliseconds: 250);

  /// Entrance of a single element (fade + slide up).
  static const Duration entrance = Duration(milliseconds: 350);

  /// Press-down leg of a tap (scale 1.0 -> pressed).
  static const Duration pressDown = Duration(milliseconds: 120);

  /// Press-release leg of a tap (scale pressed -> 1.0).
  static const Duration pressUp = Duration(milliseconds: 180);

  /// Delay added per item in a staggered sequence.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Page route transitions.
  static const Duration page = Duration(milliseconds: 320);
}

abstract final class AppCurves {
  const AppCurves._();

  /// Default decelerate curve for entrances and implicit animations.
  static const Curve standard = Curves.easeOutCubic;

  /// Material 3 "emphasized" easing for expressive motion.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Press-down easing.
  static const Curve pressDown = Curves.easeOut;

  /// Press-release easing with a hint of overshoot for a "snap back".
  static const Curve pressUp = Curves.easeOutBack;

  /// Subtle overshoot for icon bounce.
  static const Curve bounce = Curves.easeOutBack;
}

/// Interaction scale factors, shared so every pressable feels identical.
abstract final class AppScale {
  const AppScale._();

  /// Card-sized surfaces press to this scale.
  static const double pressedCard = 0.97;

  /// Smaller action tiles press a touch more.
  static const double pressedAction = 0.96;

  /// Desktop/web hover lift.
  static const double hover = 1.02;
}
