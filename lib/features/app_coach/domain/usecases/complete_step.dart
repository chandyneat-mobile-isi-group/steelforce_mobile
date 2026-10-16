import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';

/// Persists a progress snapshot after a step is completed (or the tutorial
/// finishes). Single responsibility: durable save so progress resumes later.
class CompleteStep {
  const CompleteStep(this._repository);
  final CoachRepository _repository;

  Future<void> call(CoachProgress progress) =>
      _repository.saveProgress(progress);
}
