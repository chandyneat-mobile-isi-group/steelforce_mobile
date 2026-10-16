import 'package:flutter/animation.dart';

/// Timing for the splash — now just the brand moment.
///
/// The seven-scene story that used to live here (route → visit → quotation →
/// success) moved to onboarding, where a first-run user actually has a reason
/// to watch it. A launch screen is not the place to tell a story: it is shown
/// dozens of times a day to someone who has already been told, and every second
/// of it is a second between them and their work.
///
/// What remains is the part worth keeping on every launch: the steel field
/// gathering into the mark.
abstract final class SplashTimeline {
  const SplashTimeline._();

  /// Long enough for the gather to read, short enough not to be noticed as a
  /// wait. Down from ten seconds, which was defensible for a one-time story and
  /// indefensible for a launch screen.
  static const Duration total = Duration(milliseconds: 2800);

  /// The field drifts, then gathers.
  static const double convergeFrom = 0.22;

  /// The mark forms while the last motes are still arriving — waiting for the
  /// field to settle first would read as two events instead of one.
  static const Interval logo =
      Interval(0.180, 0.760, curve: Curves.easeOutCubic);

  /// A beat of stillness before the hand-off. Motion that never rests reads as
  /// nervous rather than confident.
  static const Interval handoff =
      Interval(0.860, 1.000, curve: Curves.easeInCubic);
}
