import 'package:steelforce/features/app_coach/data/datasource/coach_local_datasource.dart';
import 'package:steelforce/features/app_coach/data/datasource/coach_step_catalog.dart';
import 'package:steelforce/features/app_coach/data/models/coach_progress_model.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_module.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';

class CoachRepositoryImpl implements CoachRepository {
  const CoachRepositoryImpl(this._local);
  final CoachLocalDataSource _local;

  /// The first version with lessons. Progress stored before it describes the
  /// tour alone.
  static const lessonsVersion = 11;

  @override
  int get version => CoachStepCatalog.coachVersion;

  @override
  List<CoachStep> getSteps() => CoachStepCatalog.steps;

  @override
  List<CoachModule> getModules() => CoachStepCatalog.modules;

  @override
  Future<CoachProgress> loadProgress() async {
    final stored = _local.readProgress(version);
    if (stored == null) return CoachProgress.initial(version);

    // Safe migration: a script change (new version) invalidates the old step
    // ids, so restart the walkthrough unless the user had fully completed it —
    // in which case respect their "done" and don't nag them again.
    //
    // Upgrading to the lessons (v10 → v11): a rep who finished or skipped the
    // tour keeps it finished, and starts every lesson as new — they are
    // offered from the assistant, never forced on someone who already
    // dismissed the coach once. Lessons completed in a v11+ build survive
    // later script changes: a finished lesson stays finished.
    if (stored.version != version) {
      final keepModules = stored.version >= lessonsVersion
          ? stored.completedModuleIds
          : const <String>[];
      final migrated = CoachProgress.initial(version).copyWith(
        completed: stored.completed,
        // A rep who hid the mascot is not shown it again by an update.
        mascotHidden: stored.mascotHidden,
        completedModuleIds: [
          ...keepModules,
          if (stored.completed && !keepModules.contains(CoachModuleIds.tour))
            CoachModuleIds.tour,
        ],
      );
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
