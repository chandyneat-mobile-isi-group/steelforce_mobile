import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';

/// Pure step-selection logic: given the ordered script and the current step id,
/// returns the next step, or null when the current one is the last.
///
/// Kept framework- and storage-free so it is trivially testable.
class NextStep {
  const NextStep();

  CoachStep? call(List<CoachStep> steps, String? currentId) {
    if (steps.isEmpty) return null;
    if (currentId == null) return steps.first;
    final index = steps.indexWhere((s) => s.id == currentId);
    if (index < 0) return steps.first;
    if (index >= steps.length - 1) return null;
    return steps[index + 1];
  }
}
