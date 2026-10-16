import 'package:flutter/foundation.dart';

/// Analytics events emitted by the coach. Names match the tracking spec.
enum CoachAnalyticsEvent {
  tutorialStarted('tutorial_started'),
  tutorialCompleted('tutorial_completed'),
  tutorialSkipped('tutorial_skipped'),
  tutorialStepCompleted('tutorial_step_completed'),
  tutorialResume('tutorial_resume'),
  tutorialDropoff('tutorial_dropoff');

  const CoachAnalyticsEvent(this.name);
  final String name;
}

/// Hook seam for analytics. No external provider is integrated here — swap in a
/// real implementation (Firebase, Amplitude, …) at DI time without touching the
/// bloc.
abstract interface class CoachAnalytics {
  void log(CoachAnalyticsEvent event, {Map<String, Object?> params});
}

/// Default no-op-in-release logger; prints in debug so the funnel is visible
/// during development.
class DebugCoachAnalytics implements CoachAnalytics {
  const DebugCoachAnalytics();

  @override
  void log(CoachAnalyticsEvent event,
      {Map<String, Object?> params = const {}}) {
    if (kDebugMode) {
      debugPrint('[coach] ${event.name} ${params.isEmpty ? '' : params}');
    }
  }
}
