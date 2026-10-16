import 'package:equatable/equatable.dart';

/// Persisted onboarding progress. Survives app restart and logout/login, and
/// carries a [version] so future step changes can migrate safely.
class CoachProgress extends Equatable {
  const CoachProgress({
    required this.completed,
    required this.currentStepId,
    required this.completedStepIds,
    required this.version,
  });

  /// Fresh state for a first-time user.
  factory CoachProgress.initial(int version) => CoachProgress(
        completed: false,
        currentStepId: null,
        completedStepIds: const <String>[],
        version: version,
      );

  final bool completed;
  final String? currentStepId;
  final List<String> completedStepIds;
  final int version;

  CoachProgress copyWith({
    bool? completed,
    String? currentStepId,
    List<String>? completedStepIds,
    int? version,
  }) {
    return CoachProgress(
      completed: completed ?? this.completed,
      currentStepId: currentStepId ?? this.currentStepId,
      completedStepIds: completedStepIds ?? this.completedStepIds,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props =>
      [completed, currentStepId, completedStepIds, version];
}
