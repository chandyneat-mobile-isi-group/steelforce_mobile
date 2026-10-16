import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/sync/background/background_sync_runner.dart';
import 'package:steelforce/core/sync/background/background_sync_scheduler.dart';
import 'package:steelforce/core/sync/sync_engine.dart';

final BackgroundSyncScheduler _scheduler = createBackgroundSyncScheduler();

/// Called first thing in `main`, before bootstrap opens Hive and the
/// database: lets a headless background run that is mid-drain in this process
/// finish first (up to a few seconds). A no-op on web.
Future<void> awaitBackgroundSyncHandover() =>
    _scheduler.waitForHeadlessRun(max: const Duration(seconds: 5));

/// Registers the OS background sync task. Called once from `main` after
/// bootstrap; a no-op on web. Never throws and never blocks first frame.
Future<void> startBackgroundSync() => _scheduler.start(drainInApp: _drainInApp);

/// A background wake that found the app alive in this process.
///
/// Through the [SyncEngine] when the signed-in shell has it running, so the
/// wake joins the engine's single-flight drain instead of racing it. Otherwise
/// (the OS launched the app in the background and no shell has mounted) the
/// same runner a headless wake uses.
Future<void> _drainInApp() async {
  final engine = sl<SyncEngine>();
  if (engine.isStarted) {
    // Re-probes reachability itself, so a stale snapshot cannot skip it.
    await engine.runNow();
    return;
  }
  await sl<BackgroundSyncRunner>().run(budget: const Duration(seconds: 25));
}
