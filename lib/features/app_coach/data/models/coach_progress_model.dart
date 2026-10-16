import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';

/// Hive-serialisable [CoachProgress]. Stored as a plain map so the schema stays
/// human-readable and forward/backward compatible (unknown keys ignored,
/// missing keys defaulted).
class CoachProgressModel extends CoachProgress {
  const CoachProgressModel({
    required super.completed,
    required super.currentStepId,
    required super.completedStepIds,
    required super.version,
  });

  factory CoachProgressModel.fromEntity(CoachProgress e) => CoachProgressModel(
        completed: e.completed,
        currentStepId: e.currentStepId,
        completedStepIds: e.completedStepIds,
        version: e.version,
      );

  /// Tolerant parse: any malformed field degrades to a safe default rather than
  /// throwing, so a corrupt record can never crash startup.
  factory CoachProgressModel.fromMap(
      Map<dynamic, dynamic> map, int fallbackVersion) {
    return CoachProgressModel(
      completed: map['completed'] == true,
      currentStepId: map['currentStepId'] as String?,
      completedStepIds: (map['completedStepIds'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      version:
          (map['version'] is int) ? map['version'] as int : fallbackVersion,
    );
  }

  Map<String, dynamic> toMap() => {
        'completed': completed,
        'currentStepId': currentStepId,
        'completedStepIds': completedStepIds,
        'version': version,
      };
}
