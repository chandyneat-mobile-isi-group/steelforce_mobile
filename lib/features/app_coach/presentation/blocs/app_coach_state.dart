part of 'app_coach_bloc.dart';

/// Immutable snapshot of the coach. A single state class (not a hierarchy)
/// keeps the overlay's `BlocBuilder` cheap and its `buildWhen` trivial.
class AppCoachState extends Equatable {
  const AppCoachState({
    required this.status,
    required this.steps,
    required this.index,
    required this.completedStepIds,
    this.module,
    this.failureKey,
    this.completedModuleIds = const {},
    this.interruptedModuleId,
    this.autoplay = false,
    this.mascotHidden = false,
  });

  const AppCoachState.initial()
      : status = CoachStatus.idle,
        steps = const [],
        index = -1,
        completedStepIds = const {},
        module = null,
        failureKey = null,
        completedModuleIds = const {},
        interruptedModuleId = null,
        autoplay = false,
        mascotHidden = false;

  final CoachStatus status;

  /// The running lesson's steps.
  final List<CoachStep> steps;

  /// Index of the active step in [steps], or -1 when none is showing.
  final int index;
  final Set<String> completedStepIds;

  /// The running (or paused) lesson. Null for a state built before lessons
  /// existed — read as the tour.
  final CoachModule? module;

  /// Retry guidance after the current step's operation failed; cleared when
  /// the step moves on.
  final String? failureKey;

  /// Lessons finished at least once.
  final Set<String> completedModuleIds;

  /// A practice lesson cut short by a restart — offered as "start again".
  final String? interruptedModuleId;

  /// The coach is performing the lesson's steps itself ("Watch demo").
  final bool autoplay;

  /// Skip or ✕ was tapped: no mascot on Home. Lessons open from Profile.
  final bool mascotHidden;

  CoachStep? get currentStep =>
      (index >= 0 && index < steps.length) ? steps[index] : null;

  /// True while a step should be visible on screen.
  bool get isVisible => status == CoachStatus.running && currentStep != null;

  /// True while a practice lesson is running or paused.
  bool get inPractice =>
      (module?.practice ?? false) &&
      (status == CoachStatus.running || status == CoachStatus.paused);

  /// 0..1 completion for the progress indicator.
  double get progress =>
      steps.isEmpty ? 0 : completedStepIds.length / steps.length;

  AppCoachState copyWith({
    CoachStatus? status,
    List<CoachStep>? steps,
    int? index,
    Set<String>? completedStepIds,
    CoachModule? Function()? module,
    String? Function()? failureKey,
    Set<String>? completedModuleIds,
    String? Function()? interruptedModuleId,
    bool? autoplay,
    bool? mascotHidden,
  }) {
    return AppCoachState(
      status: status ?? this.status,
      steps: steps ?? this.steps,
      index: index ?? this.index,
      completedStepIds: completedStepIds ?? this.completedStepIds,
      module: module == null ? this.module : module(),
      failureKey: failureKey == null ? this.failureKey : failureKey(),
      completedModuleIds: completedModuleIds ?? this.completedModuleIds,
      interruptedModuleId: interruptedModuleId == null
          ? this.interruptedModuleId
          : interruptedModuleId(),
      autoplay: autoplay ?? this.autoplay,
      mascotHidden: mascotHidden ?? this.mascotHidden,
    );
  }

  @override
  List<Object?> get props => [
        status,
        steps,
        index,
        completedStepIds,
        module?.id,
        failureKey,
        completedModuleIds,
        interruptedModuleId,
        autoplay,
        mascotHidden,
      ];
}
