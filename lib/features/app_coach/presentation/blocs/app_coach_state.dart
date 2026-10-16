part of 'app_coach_bloc.dart';

/// Immutable snapshot of the coach. A single state class (not a hierarchy)
/// keeps the overlay's `BlocBuilder` cheap and its `buildWhen` trivial.
class AppCoachState extends Equatable {
  const AppCoachState({
    required this.status,
    required this.steps,
    required this.index,
    required this.completedStepIds,
  });

  const AppCoachState.initial()
      : status = CoachStatus.idle,
        steps = const [],
        index = -1,
        completedStepIds = const {};

  final CoachStatus status;
  final List<CoachStep> steps;

  /// Index of the active step in [steps], or -1 when none is showing.
  final int index;
  final Set<String> completedStepIds;

  CoachStep? get currentStep =>
      (index >= 0 && index < steps.length) ? steps[index] : null;

  /// True while a step should be visible on screen.
  bool get isVisible => status == CoachStatus.running && currentStep != null;

  /// 0..1 completion for the progress indicator.
  double get progress =>
      steps.isEmpty ? 0 : completedStepIds.length / steps.length;

  AppCoachState copyWith({
    CoachStatus? status,
    List<CoachStep>? steps,
    int? index,
    Set<String>? completedStepIds,
  }) {
    return AppCoachState(
      status: status ?? this.status,
      steps: steps ?? this.steps,
      index: index ?? this.index,
      completedStepIds: completedStepIds ?? this.completedStepIds,
    );
  }

  @override
  List<Object?> get props => [status, steps, index, completedStepIds];
}
