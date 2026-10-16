part of 'app_coach_bloc.dart';

sealed class AppCoachEvent extends Equatable {
  const AppCoachEvent();
  @override
  List<Object?> get props => const [];
}

/// Fired once at app launch: loads persisted progress and starts/resumes the
/// tutorial for first-time users (no-op if already completed).
class CoachStarted extends AppCoachEvent {
  const CoachStarted();
}

/// A real UI action happened (tab switch, button tap). Advances the current
/// step only when it matches the step's [CoachStep.requiredAction].
class CoachActionTriggered extends AppCoachEvent {
  const CoachActionTriggered(this.action);
  final CoachAction action;
  @override
  List<Object?> get props => [action];
}

/// The bubble's primary CTA was pressed. Advances informational steps; on
/// action steps this acts as "skip this step".
class CoachCtaPressed extends AppCoachEvent {
  const CoachCtaPressed();
}

/// User dismissed the overlay — pause and surface the floating assistant.
class CoachPaused extends AppCoachEvent {
  const CoachPaused();
}

/// Resume from a paused state (floating assistant tapped).
class CoachResumed extends AppCoachEvent {
  const CoachResumed();
}

/// Skip the whole tutorial.
class CoachSkipped extends AppCoachEvent {
  const CoachSkipped();
}

/// Restart from the first step.
class CoachRestarted extends AppCoachEvent {
  const CoachRestarted();
}
