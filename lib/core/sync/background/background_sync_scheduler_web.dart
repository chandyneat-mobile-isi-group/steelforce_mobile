import 'package:steelforce/core/sync/background/background_sync_scheduler_api.dart';

/// Web: no background execution in this build (ADR-010). The foreground
/// `SyncEngine` sends while the tab is open, which is the only time a browser
/// session holds anything to send.
class _NoopBackgroundSyncScheduler implements BackgroundSyncScheduler {
  const _NoopBackgroundSyncScheduler();

  @override
  Future<void> start({required Future<void> Function() drainInApp}) async {}

  @override
  Future<void> waitForHeadlessRun({required Duration max}) async {}
}

BackgroundSyncScheduler createBackgroundSyncScheduler() =>
    const _NoopBackgroundSyncScheduler();
