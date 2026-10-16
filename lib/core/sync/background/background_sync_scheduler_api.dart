/// Hands sending to the OS while the app is closed or backgrounded.
abstract interface class BackgroundSyncScheduler {
  /// Registers the periodic background task, and lets a background wake reach
  /// the running app. Idempotent; never throws.
  ///
  /// [drainInApp] runs when the OS wakes the worker while this app's main
  /// isolate is alive (backgrounded, or open). The worker then hands the
  /// drain to the live app instead of opening the encrypted database and Hive
  /// a second time from another isolate — neither is safe to share that way.
  Future<void> start({required Future<void> Function() drainInApp});

  /// Called first thing at app launch, before Hive or the database open.
  ///
  /// If a headless background run is mid-drain in this process, waits up to
  /// [max] for it to finish, so the app does not open Hive — which is not
  /// safe to share between isolates — while the run still holds it. Past
  /// [max] the app opens anyway: a launch is never held hostage. Never throws.
  Future<void> waitForHeadlessRun({required Duration max});
}
