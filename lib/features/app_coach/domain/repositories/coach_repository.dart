import 'package:steelforce/features/app_coach/domain/entities/coach_module.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_progress.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';

/// Contract for the App Coach data layer.
///
/// Intentionally returns plain values (not `Result`): this is a purely-local,
/// non-failing UX feature whose implementation swallows storage errors and
/// falls back to sane defaults, so the coach can never crash the app.
abstract interface class CoachRepository {
  /// The first-run tour's ordered steps (const catalog — cheap, synchronous).
  List<CoachStep> getSteps();

  /// Every lesson, the tour first.
  List<CoachModule> getModules();

  /// Current coach schema version (bumped when [getSteps] changes materially).
  int get version;

  /// Loads persisted progress, applying safe migration when the stored version
  /// differs. Never throws — returns a fresh [CoachProgress.initial] on error.
  Future<CoachProgress> loadProgress();

  /// Persists a progress snapshot. Never throws.
  Future<void> saveProgress(CoachProgress progress);

  /// Wipes progress back to a first-run state (used by "Restart tutorial").
  Future<void> reset();
}
