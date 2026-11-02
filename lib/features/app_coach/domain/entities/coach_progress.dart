import 'package:equatable/equatable.dart';

/// Persisted onboarding progress. Survives app restart and logout/login, and
/// carries a [version] so future step changes can migrate safely.
///
/// [completed], [currentStepId] and [completedStepIds] describe the first-run
/// **tour** — the fields the original single-tutorial coach stored, kept with
/// their meaning so older progress reads back unchanged. The lessons add
/// [completedModuleIds] and [activeModuleId].
class CoachProgress extends Equatable {
  const CoachProgress({
    required this.completed,
    required this.currentStepId,
    required this.completedStepIds,
    required this.version,
    this.completedModuleIds = const <String>[],
    this.activeModuleId,
    this.mascotHidden = false,
  });

  /// Fresh state for a first-time user.
  factory CoachProgress.initial(int version) => CoachProgress(
        completed: false,
        currentStepId: null,
        completedStepIds: const <String>[],
        version: version,
      );

  /// The tour is finished or was skipped — it never auto-starts again.
  final bool completed;
  final String? currentStepId;
  final List<String> completedStepIds;
  final int version;

  /// Lessons finished at least once.
  final List<String> completedModuleIds;

  /// The lesson that was running when the app last saved. A practice lesson
  /// cannot resume mid-way after a restart — its demo data lived in memory —
  /// so on the next launch this reads as "interrupted, start again".
  final String? activeModuleId;

  /// The rep tapped Skip or ✕ on the coach: the mascot stays off Home for
  /// good. The lessons are still on the Profile screen.
  final bool mascotHidden;

  CoachProgress copyWith({
    bool? completed,
    String? currentStepId,
    List<String>? completedStepIds,
    int? version,
    List<String>? completedModuleIds,
    String? Function()? activeModuleId,
    bool? mascotHidden,
  }) {
    return CoachProgress(
      completed: completed ?? this.completed,
      currentStepId: currentStepId ?? this.currentStepId,
      completedStepIds: completedStepIds ?? this.completedStepIds,
      version: version ?? this.version,
      completedModuleIds: completedModuleIds ?? this.completedModuleIds,
      activeModuleId:
          activeModuleId == null ? this.activeModuleId : activeModuleId(),
      mascotHidden: mascotHidden ?? this.mascotHidden,
    );
  }

  @override
  List<Object?> get props => [
        completed,
        currentStepId,
        completedStepIds,
        version,
        completedModuleIds,
        activeModuleId,
        mascotHidden,
      ];
}
