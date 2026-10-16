import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';

/// Resumes (or starts) the tutorial by loading persisted progress.
class StartTutorial {
  const StartTutorial(this._repository);
  final CoachRepository _repository;

  Future<CoachProgress> call() => _repository.loadProgress();
}
