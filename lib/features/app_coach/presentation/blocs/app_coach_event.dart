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

/// Starts — or restarts from its first step — the lesson [moduleId]. A
/// practice lesson opens a fresh practice session.
class CoachModuleStarted extends AppCoachEvent {
  const CoachModuleStarted(this.moduleId, {this.autoplay = false});
  final String moduleId;

  /// "Watch demo": the coach performs each step itself (practice only).
  final bool autoplay;
  @override
  List<Object?> get props => [moduleId, autoplay];
}

/// Autoplay on ("Auto-play") or off ("Take over"). Practice lessons only.
class CoachAutoplayChanged extends AppCoachEvent {
  const CoachAutoplayChanged(this.enabled, {this.reasonKey});
  final bool enabled;

  /// Why autoplay stopped by itself, shown in the guide (null when the rep
  /// chose to take over).
  final String? reasonKey;
  @override
  List<Object?> get props => [enabled, reasonKey];
}

/// A real UI action happened (tab switch, button tap, confirmed save). Moves
/// the coach only when it matches the running step — see [AppCoachBloc].
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

/// Skip the running lesson. The tour is marked done; a practice lesson is
/// left unfinished and its practice data discarded.
class CoachSkipped extends AppCoachEvent {
  const CoachSkipped();
}

/// Restart the first-run tour from its first step.
class CoachRestarted extends AppCoachEvent {
  const CoachRestarted();
}

/// Skip or ✕ was tapped on the coach: hide the mascot from Home for good.
/// Saved, so it stays hidden after a restart.
class CoachMascotHidden extends AppCoachEvent {
  const CoachMascotHidden();
}
