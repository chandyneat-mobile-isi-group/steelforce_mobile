import 'package:steelforce/core/database/hive/hive_service.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/sync/background/background_sync_runner.dart';

/// Entry point for one background sync run, from whichever isolate the OS
/// woke.
///
/// That is usually a fresh, headless isolate with nothing initialised — so this
/// performs the parts of [AppBootstrapService.run] that sending needs (Hive,
/// then DI, which opens the encrypted database lazily with the device-bound
/// key) and nothing else: no legacy imports, no UI, no push.
///
/// It can also be the app's own main isolate — workmanager runs one-off tasks
/// on the live engine when the app is up — so every step checks whether it is
/// already done. Initialising DI twice would throw on the first duplicate
/// registration.
///
/// Platform-agnostic on purpose: the workmanager glue that calls this is
/// native-only, and keeping this file free of it keeps the web build clean.
Future<BackgroundSyncOutcome> runBackgroundSync({
  required Duration budget,
}) async {
  const AppLogger logger = ConsoleAppLogger();
  try {
    if (!sl.isRegistered<BackgroundSyncRunner>()) {
      await HiveService.init();
      await initDependencies();
    }
  } catch (e, stack) {
    // Most likely the cipher open from a background isolate — the hazard
    // `docs/blueprint/sync-architecture.md` §8 flags. Logged, never thrown: the
    // foreground path still delivers everything on the next open.
    logger.error('sync.background.bootstrap_failed',
        error: e, stackTrace: stack);
    return BackgroundSyncOutcome.failed;
  }
  return sl<BackgroundSyncRunner>().run(budget: budget);
}
