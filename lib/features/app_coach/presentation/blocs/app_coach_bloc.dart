import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_status.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';
import 'package:steelforce/features/app_coach/domain/usecases/complete_step.dart';
import 'package:steelforce/features/app_coach/domain/usecases/next_step.dart';
import 'package:steelforce/features/app_coach/domain/usecases/skip_tutorial.dart';
import 'package:steelforce/features/app_coach/domain/usecases/start_tutorial.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_analytics.dart';

part 'app_coach_event.dart';
part 'app_coach_state.dart';

/// Orchestrates the App Coach: owns the running step, validates user actions,
/// persists progress after every transition, and emits analytics hooks.
///
/// Registered as a **singleton** so any widget (deep in the tree, or with no
/// coach `BlocProvider` above it) can drive it via the `AppCoach` facade, and so
/// state survives tab switches inside `MainShell`'s `IndexedStack`.
class AppCoachBloc extends Bloc<AppCoachEvent, AppCoachState> {
  AppCoachBloc({
    required CoachRepository repository,
    required StartTutorial startTutorial,
    required CompleteStep completeStep,
    required SkipTutorial skipTutorial,
    required NextStep nextStep,
    CoachAnalytics analytics = const DebugCoachAnalytics(),
  })  : _repository = repository,
        _startTutorial = startTutorial,
        _completeStep = completeStep,
        _skipTutorial = skipTutorial,
        _nextStep = nextStep,
        _analytics = analytics,
        super(const AppCoachState.initial()) {
    on<CoachStarted>(_onStarted);
    on<CoachActionTriggered>(_onAction);
    on<CoachCtaPressed>(_onCta);
    on<CoachPaused>(_onPaused);
    on<CoachResumed>(_onResumed);
    on<CoachSkipped>(_onSkipped);
    on<CoachRestarted>(_onRestarted);
  }

  final CoachRepository _repository;
  final StartTutorial _startTutorial;
  final CompleteStep _completeStep;
  final SkipTutorial _skipTutorial;
  final NextStep _nextStep;
  final CoachAnalytics _analytics;

  List<CoachStep> get _steps => _repository.getSteps();

  Future<void> _onStarted(CoachStarted e, Emitter<AppCoachState> emit) async {
    // Guard against a double-start (e.g. shell rebuilds) once already running.
    if (state.status == CoachStatus.running ||
        state.status == CoachStatus.paused) {
      return;
    }

    final steps = _steps;
    final progress = await _startTutorial();

    if (progress.completed || steps.isEmpty) {
      emit(state.copyWith(status: CoachStatus.completed, steps: steps));
      return;
    }

    final resumeIndex = _resumeIndex(steps, progress);
    final resuming = progress.completedStepIds.isNotEmpty;
    _analytics.log(resuming
        ? CoachAnalyticsEvent.tutorialResume
        : CoachAnalyticsEvent.tutorialStarted);

    emit(state.copyWith(
      status: CoachStatus.running,
      steps: steps,
      index: resumeIndex,
      completedStepIds: progress.completedStepIds.toSet(),
    ));
  }

  void _onAction(CoachActionTriggered e, Emitter<AppCoachState> emit) {
    final step = state.currentStep;
    if (state.status != CoachStatus.running || step == null) return;
    if (step.isInformational || step.requiredAction != e.action) return;
    _advance(emit);
  }

  void _onCta(CoachCtaPressed e, Emitter<AppCoachState> emit) {
    if (state.status != CoachStatus.running || state.currentStep == null) {
      return;
    }
    // Informational steps advance; action steps treat CTA as "skip this step".
    _advance(emit);
  }

  void _onPaused(CoachPaused e, Emitter<AppCoachState> emit) {
    if (state.status != CoachStatus.running) return;
    _analytics.log(CoachAnalyticsEvent.tutorialDropoff,
        params: {'step': state.currentStep?.id});
    emit(state.copyWith(status: CoachStatus.paused));
  }

  void _onResumed(CoachResumed e, Emitter<AppCoachState> emit) {
    if (state.status != CoachStatus.paused) return;
    _analytics.log(CoachAnalyticsEvent.tutorialResume,
        params: {'step': state.currentStep?.id});
    emit(state.copyWith(status: CoachStatus.running));
  }

  Future<void> _onSkipped(CoachSkipped e, Emitter<AppCoachState> emit) async {
    _analytics.log(CoachAnalyticsEvent.tutorialSkipped,
        params: {'step': state.currentStep?.id});
    await _skipTutorial(_snapshot());
    emit(state.copyWith(status: CoachStatus.completed));
  }

  Future<void> _onRestarted(
      CoachRestarted e, Emitter<AppCoachState> emit) async {
    await _repository.reset();
    final steps = _steps;
    _analytics
        .log(CoachAnalyticsEvent.tutorialStarted, params: {'restart': true});
    emit(state.copyWith(
      status: steps.isEmpty ? CoachStatus.completed : CoachStatus.running,
      steps: steps,
      index: steps.isEmpty ? -1 : 0,
      completedStepIds: const {},
    ));
    await _persist();
  }

  // ── Internal helpers ──────────────────────────────────────────────────

  /// Marks the current step complete and moves to the next one, or finishes.
  void _advance(Emitter<AppCoachState> emit) {
    final current = state.currentStep;
    if (current == null) return;

    final completed = {...state.completedStepIds, current.id};
    final next = _nextStep(state.steps, current.id);

    _analytics.log(CoachAnalyticsEvent.tutorialStepCompleted,
        params: {'step': current.id});

    if (next == null) {
      _analytics.log(CoachAnalyticsEvent.tutorialCompleted);
      emit(state.copyWith(
        status: CoachStatus.completed,
        completedStepIds: completed,
      ));
      _persist(); // fire-and-forget durable save
      return;
    }

    emit(state.copyWith(
      index: state.index + 1,
      completedStepIds: completed,
    ));
    _persist();
  }

  int _resumeIndex(List<CoachStep> steps, CoachProgress progress) {
    final done = progress.completedStepIds.toSet();
    final i = steps.indexWhere((s) => !done.contains(s.id));
    return i < 0 ? steps.length - 1 : i;
  }

  CoachProgress _snapshot() => CoachProgress(
        completed: state.status == CoachStatus.completed,
        currentStepId: state.currentStep?.id,
        completedStepIds: state.completedStepIds.toList(growable: false),
        version: _repository.version,
      );

  Future<void> _persist() => _completeStep(_snapshot());
}
