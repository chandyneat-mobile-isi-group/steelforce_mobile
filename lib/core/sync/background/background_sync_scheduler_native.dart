import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:steelforce/core/bootstrap/background_sync_bootstrap.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/sync/background/background_sync_scheduler_api.dart';
import 'package:steelforce/core/sync/background/sync_run_context.dart';
import 'package:workmanager/workmanager.dart';

/// The task's identity on both platforms. On iOS it must also be listed under
/// `BGTaskSchedulerPermittedIdentifiers` in `ios/Runner/Info.plist` and
/// registered in `AppDelegate.swift` — change all three together.
const String backgroundSyncTaskId = 'com.isigroup.steelforce.sync';

/// Where the app's main isolate listens for a background wake.
const String _mainPortName = 'isi.sync.main_isolate';

/// Where a headless run announces itself while it holds Hive and the database.
const String _headlessPortName = 'isi.sync.headless_run';

/// Messages on the handoff channel.
const String _ack = 'ack';
const String _done = 'done';

/// How long a worker waits for the app to acknowledge a handoff before
/// deciding the port is stale. Port mappings outlive the isolate that
/// registered them — Android keeps the process (and the mapping) after the
/// activity is gone — and without this every run would wait out its whole
/// budget sending to nobody.
const Duration _ackTimeout = Duration(seconds: 3);

/// Android WorkManager's floor for periodic work. iOS treats it as a hint and
/// schedules by its own heuristics (usage, battery, connectivity).
const Duration _frequency = Duration(minutes: 15);

/// How long a run may take. iOS gives a `BGAppRefreshTask` about 30 seconds
/// before it kills the process; Android allows ten minutes per worker.
Duration get _budget =>
    Platform.isIOS ? const Duration(seconds: 25) : const Duration(minutes: 8);

class _WorkmanagerBackgroundSyncScheduler implements BackgroundSyncScheduler {
  ReceivePort? _port;

  @override
  Future<void> start({required Future<void> Function() drainInApp}) async {
    const AppLogger logger = ConsoleAppLogger();
    try {
      _listen(drainInApp);
      await Workmanager().initialize(backgroundSyncDispatcher);
      await Workmanager().registerPeriodicTask(
        backgroundSyncTaskId,
        backgroundSyncTaskId,
        frequency: _frequency,
        // A run with no network can only find out it is offline.
        constraints: Constraints(networkType: NetworkType.connected),
        // Keep the existing schedule across launches rather than resetting
        // its clock every time the app opens.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      logger.info('sync.background.scheduled');
    } catch (e, stack) {
      // Background sync is a supplement; the foreground engine still sends.
      logger.error('sync.background.schedule_failed',
          error: e, stackTrace: stack);
    }
  }

  @override
  Future<void> waitForHeadlessRun({required Duration max}) async {
    final headless = IsolateNameServer.lookupPortByName(_headlessPortName);
    if (headless == null) return;
    final reply = ReceivePort();
    try {
      headless.send(reply.sendPort);
      // The run answers when it is finished; a dead mapping never answers.
      await reply.first.timeout(max);
    } catch (_) {
      // Waited long enough. Clear a mapping no live run will ever answer on.
      IsolateNameServer.removePortNameMapping(_headlessPortName);
    } finally {
      reply.close();
    }
  }

  /// Lets a background wake hand its drain to this (main) isolate. The worker
  /// sends a reply port; this acknowledges at once (proving the port is
  /// live), runs the drain on the app's own open database and Hive boxes, and
  /// then tells the worker it may finish.
  void _listen(Future<void> Function() drainInApp) {
    if (_port != null) return;
    final port = ReceivePort();
    port.listen((message) async {
      if (message is! SendPort) return;
      message.send(_ack);
      try {
        // An iOS refresh task has ~25 s: don't start a registration it cannot
        // finish (see [SyncRunContext]).
        await SyncRunContext.withBudget(_budget, drainInApp);
      } catch (_) {
        // The drain logs its own failures; the worker must still be released.
      } finally {
        message.send(_done);
      }
    });
    _port = port;
    IsolateNameServer.removePortNameMapping(_mainPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, _mainPortName);
  }
}

BackgroundSyncScheduler createBackgroundSyncScheduler() =>
    _WorkmanagerBackgroundSyncScheduler();

/// What the OS calls. Must be top-level and kept by the tree shaker.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final budget = _budget;
    if (await _handOffToApp(budget)) return true;

    // Nobody home: a headless wake. Announce it, so an app launched meanwhile
    // waits before opening Hive, then boot just enough to send.
    final waiters = <SendPort>[];
    final announce = ReceivePort()
      ..listen((m) {
        if (m is SendPort) waiters.add(m);
      });
    IsolateNameServer.removePortNameMapping(_headlessPortName);
    IsolateNameServer.registerPortWithName(
        announce.sendPort, _headlessPortName);
    try {
      await runBackgroundSync(budget: budget);
    } finally {
      IsolateNameServer.removePortNameMapping(_headlessPortName);
      for (final w in waiters) {
        w.send(_done);
      }
      announce.close();
    }
    // Always true. False asks Android to retry with backoff, but every outbox
    // already schedules its own retries and the next periodic run comes anyway.
    return true;
  });
}

/// Hands the drain to the app's main isolate if it is alive in this process.
/// False when there is no app, or its port is a stale mapping.
Future<bool> _handOffToApp(Duration budget) async {
  final main = IsolateNameServer.lookupPortByName(_mainPortName);
  if (main == null) return false;

  final reply = ReceivePort();
  final messages = StreamIterator<dynamic>(reply);
  try {
    main.send(reply.sendPort);
    final acked =
        await messages.moveNext().timeout(_ackTimeout, onTimeout: () => false);
    if (!acked || messages.current != _ack) {
      // Registered by an isolate that no longer exists.
      IsolateNameServer.removePortNameMapping(_mainPortName);
      return false;
    }
    // Live: wait for the app's drain, within the OS budget.
    await messages.moveNext().timeout(budget, onTimeout: () => false);
    return true;
  } finally {
    await messages.cancel();
    reply.close();
  }
}
