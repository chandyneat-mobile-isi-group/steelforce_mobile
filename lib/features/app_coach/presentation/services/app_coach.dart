import 'package:get_it/get_it.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';

/// Thin, context-free facade over the singleton [AppCoachBloc].
///
/// Lets any widget report a real user action to the coach in one safe line:
/// `AppCoach.notify(CoachAction.createLead);` — a no-op when the coach isn't
/// registered or isn't running, so call sites never need to know coach state
/// and existing features stay decoupled.
abstract final class AppCoach {
  static AppCoachBloc? get _bloc =>
      GetIt.I.isRegistered<AppCoachBloc>() ? GetIt.I<AppCoachBloc>() : null;

  /// Report that the user performed [action]. Advances the tutorial only if the
  /// active step was waiting for exactly this action.
  static void notify(CoachAction action) =>
      _bloc?.add(CoachActionTriggered(action));

  /// Load + start/resume the tutorial for first-time users. Safe to call more
  /// than once (the bloc guards against re-entry).
  static void start() => _bloc?.add(const CoachStarted());

  /// Restart the walkthrough from step one (e.g. from a Help menu).
  static void restart() => _bloc?.add(const CoachRestarted());
}
