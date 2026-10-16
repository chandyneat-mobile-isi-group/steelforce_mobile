import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';

/// Marks the whole tutorial completed (user chose "Skip") and persists it so it
/// never auto-starts again.
class SkipTutorial {
  const SkipTutorial(this._repository);
  final CoachRepository _repository;

  Future<void> call(CoachProgress current) =>
      _repository.saveProgress(current.copyWith(completed: true));
}
