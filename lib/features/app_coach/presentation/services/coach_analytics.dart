import 'package:flutter/foundation.dart';

/// Analytics events emitted by the coach. Names match the tracking spec.
///
/// Parameters are coach vocabulary only — a lesson id, a step id, an action
/// name, an outcome. Never a depot name, a phone number, a price, a photo or
/// anything else a rep typed (security.md §3).
enum CoachAnalyticsEvent {
  tutorialStarted('tutorial_started'),
  tutorialCompleted('tutorial_completed'),
  tutorialSkipped('tutorial_skipped'),
  tutorialRestarted('tutorial_restarted'),
  tutorialStepCompleted('tutorial_step_completed'),
  tutorialResume('tutorial_resume'),
  tutorialDropoff('tutorial_dropoff'),

  /// A lesson's real operation came back: `{module, action}` — e.g.
  /// `createDepotSucceeded`, `checkInFailed`.
  operationSucceeded('tutorial_operation_succeeded'),
  operationFailed('tutorial_operation_failed');

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
