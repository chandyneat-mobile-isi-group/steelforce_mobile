import 'package:steelforce/features/app_coach/data/datasource/coach_local_datasource.dart';
import 'package:steelforce/features/app_coach/data/datasource/coach_step_catalog.dart';
import 'package:steelforce/features/app_coach/data/models/coach_progress_model.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';

class CoachRepositoryImpl implements CoachRepository {
  const CoachRepositoryImpl(this._local);
  final CoachLocalDataSource _local;

  @override
  int get version => CoachStepCatalog.coachVersion;

  @override
  List<CoachStep> getSteps() => CoachStepCatalog.steps;

  @override
  Future<CoachProgress> loadProgress() async {
    final stored = _local.readProgress(version);
    if (stored == null) return CoachProgress.initial(version);

    // Safe migration: a script change (new version) invalidates the old step
    // ids, so restart the walkthrough unless the user had fully completed it —
    // in which case respect their "done" and don't nag them again.
    if (stored.version != version) {
      final migrated = stored.completed
          ? CoachProgress.initial(version).copyWith(completed: true)
          : CoachProgress.initial(version);
      await saveProgress(migrated);
      return migrated;
    }
    return stored;
  }

  @override
  Future<void> saveProgress(CoachProgress progress) =>
      _local.writeProgress(CoachProgressModel.fromEntity(progress));

  @override
  Future<void> reset() => _local.clear();
}
