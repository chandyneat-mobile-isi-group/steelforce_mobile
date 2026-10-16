/// Platform-selected background sync scheduler.
///
/// Both sides expose `BackgroundSyncScheduler createBackgroundSyncScheduler()`.
/// Native registers a periodic OS task (Android WorkManager, iOS
/// BGTaskScheduler) through the `workmanager` plugin; web is a no-op — a
/// browser has no background execution in this build (ADR-010), and the
/// foreground [SyncEngine] covers it while the tab is open.
///
/// A conditional export rather than a `kIsWeb` branch, so `workmanager` (which
/// imports `dart:io`) never enters the web compilation unit. Same pattern as
/// `push_messaging_service_factory.dart`.
library;

export 'background_sync_scheduler_api.dart';
export 'background_sync_scheduler_web.dart'
    if (dart.library.io) 'background_sync_scheduler_native.dart';
