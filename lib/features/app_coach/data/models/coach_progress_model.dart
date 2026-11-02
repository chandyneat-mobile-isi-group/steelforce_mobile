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
    super.completedModuleIds,
    super.activeModuleId,
    super.mascotHidden,
  });

  factory CoachProgressModel.fromEntity(CoachProgress e) => CoachProgressModel(
        completed: e.completed,
        currentStepId: e.currentStepId,
        completedStepIds: e.completedStepIds,
        version: e.version,
        completedModuleIds: e.completedModuleIds,
        activeModuleId: e.activeModuleId,
        mascotHidden: e.mascotHidden,
      );

  /// Tolerant parse: any malformed field degrades to a safe default rather than
  /// throwing, so a corrupt record can never crash startup.
  factory CoachProgressModel.fromMap(
      Map<dynamic, dynamic> map, int fallbackVersion) {
    List<String> strings(Object? v) => v is List
        ? v.whereType<String>().toList(growable: false)
        : const <String>[];
    String? string(Object? v) => v is String ? v : null;

    return CoachProgressModel(
      completed: map['completed'] == true,
      currentStepId: string(map['currentStepId']),
      completedStepIds: strings(map['completedStepIds']),
      version:
          (map['version'] is int) ? map['version'] as int : fallbackVersion,
      // Absent before the lessons existed (coach v10 and earlier).
      completedModuleIds: strings(map['completedModuleIds']),
      activeModuleId: string(map['activeModuleId']),
      // Absent before the mascot could be hidden: shown.
      mascotHidden: map['mascotHidden'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'completed': completed,
        'currentStepId': currentStepId,
        'completedStepIds': completedStepIds,
        'version': version,
        'completedModuleIds': completedModuleIds,
        'activeModuleId': activeModuleId,
        'mascotHidden': mascotHidden,
      };
}
