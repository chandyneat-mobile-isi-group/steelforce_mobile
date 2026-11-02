import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_module.dart';
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
///
/// ## Lessons
///
/// The first-run tour is one lesson; the others (depots, quotation, order,
/// visit) are started from the lessons list and run as practice — this bloc
/// opens the [PracticeSession] when one starts and closes it whenever it ends,
/// however it ends (finished, skipped, replaced by another lesson).
///
/// ## What moves a step
///
/// * Its `requiredAction` — and only that. Opening a screen is its own
///   action, distinct from the confirmed result of the operation on it.
/// * Its `failureAction` never advances: it shows the step's retry guidance.
/// * In a practice lesson, a rep who has already done a *later* step's action
///   (saved before the coach asked) moves on to it. Actions for earlier steps,
///   repeats, and actions no step asks for are ignored.
class AppCoachBloc extends Bloc<AppCoachEvent, AppCoachState> {
  AppCoachBloc({
    required CoachRepository repository,
    required StartTutorial startTutorial,
    required CompleteStep completeStep,
    required SkipTutorial skipTutorial,
    required NextStep nextStep,
    PracticeSession? practice,
    CoachAnalytics analytics = const DebugCoachAnalytics(),
  })  : _repository = repository,
        _startTutorial = startTutorial,
        _completeStep = completeStep,
        _skipTutorial = skipTutorial,
        _nextStep = nextStep,
        _practice = practice,
        _analytics = analytics,
        super(const AppCoachState.initial()) {
    on<CoachStarted>(_onStarted);
    on<CoachModuleStarted>(_onModuleStarted, transformer: restartable());
    // In arrival order: a success and the tap that follows it must not race,
    // or the second would be judged against a step the first already left.
    on<CoachActionTriggered>(_onAction, transformer: sequential());
    on<CoachCtaPressed>(_onCta, transformer: droppable());
    on<CoachPaused>(_onPaused);
    on<CoachResumed>(_onResumed);
    on<CoachSkipped>(_onSkipped);
    on<CoachRestarted>(_onRestarted);
    on<CoachAutoplayChanged>(_onAutoplayChanged);
    on<CoachMascotHidden>(_onMascotHidden);
  }

  final CoachRepository _repository;
  final StartTutorial _startTutorial;
  final CompleteStep _completeStep;
  final SkipTutorial _skipTutorial;
  final NextStep _nextStep;
  final PracticeSession? _practice;
  final CoachAnalytics _analytics;

  /// What is on disk. Every transition updates it and saves it whole.
  CoachProgress? _progress;

  List<CoachStep> get _steps => _repository.getSteps();

  CoachModule get _tour {
    for (final m in _repository.getModules()) {
      if (m.id == CoachModuleIds.tour) return m;
    }
    return CoachModule(
      id: CoachModuleIds.tour,
      titleKey: '',
      summaryKey: '',
      steps: _steps,
      practice: false,
    );
  }

  CoachModule? _moduleById(String? id) {
    for (final m in _repository.getModules()) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The running lesson; a state with none is the tour.
  CoachModule get _module => state.module ?? _tour;

  Map<String, Object?> _params([Map<String, Object?> extra = const {}]) =>
      {'module': _module.id, ...extra};

  Future<void> _onStarted(CoachStarted e, Emitter<AppCoachState> emit) async {
    // Guard against a double-start (e.g. shell rebuilds) once already running.
    if (state.status == CoachStatus.running ||
        state.status == CoachStatus.paused) {
      return;
    }

    final progress = await _startTutorial();
    _progress = progress;
    emit(state.copyWith(mascotHidden: progress.mascotHidden));
    final tour = _tour;
    final steps = tour.steps;
    final done = progress.completedModuleIds.toSet();
    // A practice lesson's demo data lived in memory; after a restart it can
    // only be started again, not resumed.
    final interrupted = _moduleById(progress.activeModuleId);
    final interruptedId =
        (interrupted?.practice ?? false) ? interrupted!.id : null;

    if (progress.completed || steps.isEmpty) {
      emit(state.copyWith(
        status: CoachStatus.completed,
        steps: steps,
        module: () => tour,
        completedModuleIds: done,
        interruptedModuleId: () => interruptedId,
      ));
      return;
    }

    final resumeIndex = _resumeIndex(steps, progress.completedStepIds.toSet());
    final resuming = progress.completedStepIds.isNotEmpty;
    _analytics.log(
      resuming
          ? CoachAnalyticsEvent.tutorialResume
          : CoachAnalyticsEvent.tutorialStarted,
      params: {'module': tour.id},
    );

    emit(state.copyWith(
      status: CoachStatus.running,
      steps: steps,
      index: resumeIndex,
      completedStepIds: progress.completedStepIds.toSet(),
      module: () => tour,
      failureKey: () => null,
      completedModuleIds: done,
      interruptedModuleId: () => interruptedId,
    ));
  }

  Future<void> _onModuleStarted(
      CoachModuleStarted e, Emitter<AppCoachState> emit) async {
    final module = _moduleById(e.moduleId);
    if (module == null || module.steps.isEmpty) return;

    _progress ??= await _startTutorial();
    final restarting = state.module?.id == module.id &&
        (state.status == CoachStatus.running ||
            state.status == CoachStatus.paused);

    if (module.practice) {
      // Opens a fresh practice world — a restart starts from clean demo data.
      await _practice?.start(module.id);
    } else {
      await _practice?.end();
    }

    _analytics.log(
      restarting
          ? CoachAnalyticsEvent.tutorialRestarted
          : CoachAnalyticsEvent.tutorialStarted,
      params: {'module': module.id},
    );
    emit(state.copyWith(
      status: CoachStatus.running,
      steps: module.steps,
      index: 0,
      completedStepIds: const {},
      module: () => module,
      failureKey: () => null,
      interruptedModuleId: () => null,
      autoplay: module.practice && e.autoplay,
    ));
    await _save((p) => p.copyWith(
          activeModuleId: () => module.practice ? module.id : null,
          // Re-running the tour from the lessons list starts it over.
          completedStepIds: module.practice ? null : const <String>[],
          currentStepId: module.practice ? null : module.steps.first.id,
        ));
  }

  Future<void> _onAction(
      CoachActionTriggered e, Emitter<AppCoachState> emit) async {
    final step = state.currentStep;
    if (state.status != CoachStatus.running || step == null) return;

    if (!step.isInformational && step.requiredAction == e.action) {
      _logOutcome(e.action, succeeded: true);
      await _advance(emit);
      return;
    }
    if (step.failureAction != null && step.failureAction == e.action) {
      _logOutcome(e.action, succeeded: false);
      // Autoplay never retries a failure on its own: the rep reads why.
      emit(state.copyWith(
          failureKey: () => step.failureMessageKey, autoplay: false));
      return;
    }
    if (!_module.allowsSkipAhead) return;

    // A later step's milestone, done before the coach asked for it.
    final later = _laterIndex((s) => s.requiredAction == e.action);
    if (later != null) {
      _logOutcome(e.action, succeeded: true);
      await _moveTo(emit, later + 1);
      return;
    }
    // A later step's operation failed: move there and show its guidance.
    final failedAt = _laterIndex((s) => s.failureAction == e.action);
    if (failedAt != null) {
      _logOutcome(e.action, succeeded: false);
      await _moveTo(emit, failedAt,
          failureKey: state.steps[failedAt].failureMessageKey);
    }
  }

  Future<void> _onCta(CoachCtaPressed e, Emitter<AppCoachState> emit) async {
    if (state.status != CoachStatus.running || state.currentStep == null) {
      return;
    }
    // Informational steps advance; action steps treat CTA as "skip this step".
    await _advance(emit);
  }

  void _onPaused(CoachPaused e, Emitter<AppCoachState> emit) {
    if (state.status != CoachStatus.running) return;
    _analytics.log(CoachAnalyticsEvent.tutorialDropoff,
        params: _params({'step': state.currentStep?.id}));
    emit(state.copyWith(status: CoachStatus.paused, autoplay: false));
  }

  void _onAutoplayChanged(CoachAutoplayChanged e, Emitter<AppCoachState> emit) {
    if (state.status != CoachStatus.running || !_module.practice) return;
    if (state.autoplay == e.enabled && e.reasonKey == null) return;
    emit(state.copyWith(
      autoplay: e.enabled,
      // Turning it back on clears the old guidance; stopping by itself says
      // why.
      failureKey: () => e.enabled ? null : (e.reasonKey ?? state.failureKey),
    ));
  }

  void _onResumed(CoachResumed e, Emitter<AppCoachState> emit) {
    if (state.status != CoachStatus.paused) return;
    _analytics.log(CoachAnalyticsEvent.tutorialResume,
        params: _params({'step': state.currentStep?.id}));
    emit(state.copyWith(status: CoachStatus.running));
  }

  Future<void> _onSkipped(CoachSkipped e, Emitter<AppCoachState> emit) async {
    _analytics.log(CoachAnalyticsEvent.tutorialSkipped,
        params: _params({'step': state.currentStep?.id}));
    final module = _module;
    if (module.practice) {
      // Left unfinished: offered again in the lessons list, demo data gone.
      await _practice?.end();
      emit(state.copyWith(
        status: CoachStatus.completed,
        failureKey: () => null,
        autoplay: false,
      ));
      await _save((p) => p.copyWith(activeModuleId: () => null));
      return;
    }
    await _skipTutorial(_snapshot());
    _progress = _snapshot().copyWith(completed: true);
    emit(state.copyWith(status: CoachStatus.completed));
  }

  Future<void> _onRestarted(
      CoachRestarted e, Emitter<AppCoachState> emit) async {
    await _practice?.end();
    await _repository.reset();
    final tour = _tour;
    final steps = tour.steps;
    _analytics.log(CoachAnalyticsEvent.tutorialRestarted,
        params: {'module': tour.id});
    // Lessons already finished stay finished: restarting the tour is not a
    // reason to forget them.
    final keep = state.completedModuleIds
        .where((id) => id != CoachModuleIds.tour)
        .toSet();
    // Restarting the tour does not bring back a mascot the rep hid.
    _progress = CoachProgress.initial(_repository.version).copyWith(
        completedModuleIds: keep.toList(), mascotHidden: state.mascotHidden);
    emit(state.copyWith(
      status: steps.isEmpty ? CoachStatus.completed : CoachStatus.running,
      steps: steps,
      index: steps.isEmpty ? -1 : 0,
      completedStepIds: const {},
      module: () => tour,
      failureKey: () => null,
      completedModuleIds: keep,
      interruptedModuleId: () => null,
    ));
    await _persist();
  }

  Future<void> _onMascotHidden(
      CoachMascotHidden e, Emitter<AppCoachState> emit) async {
    if (state.mascotHidden) return;
    emit(state.copyWith(mascotHidden: true));
    await _save((p) => p.copyWith(mascotHidden: true));
  }

  // ── Internal helpers ──────────────────────────────────────────────────

  /// Marks the current step complete and moves to the next one, or finishes.
  Future<void> _advance(Emitter<AppCoachState> emit) async {
    final current = state.currentStep;
    if (current == null) return;

    final completed = {...state.completedStepIds, current.id};
    final next = _nextStep(state.steps, current.id);

    _analytics.log(CoachAnalyticsEvent.tutorialStepCompleted,
        params: _params({'step': current.id}));

    if (next == null) {
      await _finish(emit, completed);
      return;
    }

    emit(state.copyWith(
      index: state.index + 1,
      completedStepIds: completed,
      failureKey: () => null,
    ));
    await _persist();
  }

  /// Jumps forward to [target], counting every step passed as done.
  Future<void> _moveTo(Emitter<AppCoachState> emit, int target,
      {String? failureKey}) async {
    final passed = state.steps
        .sublist(state.index, target.clamp(state.index, state.steps.length))
        .map((s) => s.id);
    final completed = {...state.completedStepIds, ...passed};
    if (target >= state.steps.length) {
      await _finish(emit, completed);
      return;
    }
    emit(state.copyWith(
      index: target,
      completedStepIds: completed,
      failureKey: () => failureKey,
      autoplay: failureKey == null ? null : false,
    ));
    await _persist();
  }

  Future<void> _finish(
      Emitter<AppCoachState> emit, Set<String> completedSteps) async {
    final module = _module;
    _analytics.log(CoachAnalyticsEvent.tutorialCompleted,
        params: {'module': module.id});
    if (module.practice) await _practice?.end();
    final modules = {...state.completedModuleIds, module.id};
    emit(state.copyWith(
      status: CoachStatus.completed,
      completedStepIds: completedSteps,
      failureKey: () => null,
      completedModuleIds: modules,
      autoplay: false,
    ));
    await _persist();
  }

  int? _laterIndex(bool Function(CoachStep) test) {
    for (var i = state.index + 1; i < state.steps.length; i++) {
      if (test(state.steps[i])) return i;
    }
    return null;
  }

  void _logOutcome(CoachAction action, {required bool succeeded}) {
    final name = action.name;
    if (!name.endsWith('Succeeded') && !name.endsWith('Failed')) return;
    _analytics.log(
      succeeded
          ? CoachAnalyticsEvent.operationSucceeded
          : CoachAnalyticsEvent.operationFailed,
      params: _params({'action': name}),
    );
  }

  int _resumeIndex(List<CoachStep> steps, Set<String> done) {
    final i = steps.indexWhere((s) => !done.contains(s.id));
    return i < 0 ? steps.length - 1 : i;
  }

  /// The progress to store for the current state. The tour fields change only
  /// while the tour runs; a lesson changes the lesson fields.
  CoachProgress _snapshot() {
    final base = _progress ?? CoachProgress.initial(_repository.version);
    final module = _module;
    final finished = state.status == CoachStatus.completed;
    final modules = state.completedModuleIds.toList(growable: false);
    if (module.practice) {
      return base.copyWith(
        version: _repository.version,
        completedModuleIds: modules,
        activeModuleId: () => finished ? null : module.id,
      );
    }
    return base.copyWith(
      completed: finished ? true : base.completed,
      currentStepId: state.currentStep?.id,
      completedStepIds: state.completedStepIds.toList(growable: false),
      version: _repository.version,
      completedModuleIds: modules,
      activeModuleId: () => null,
    );
  }

  Future<void> _persist() async {
    final snapshot = _snapshot();
    _progress = snapshot;
    await _completeStep(snapshot);
  }

  Future<void> _save(CoachProgress Function(CoachProgress) change) async {
    final next = change(_snapshot());
    _progress = next;
    await _completeStep(next);
  }

  @override
  Future<void> close() async {
    await _practice?.end();
    return super.close();
  }
}
