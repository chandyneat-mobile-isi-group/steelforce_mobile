import 'dart:async';

import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/sync/background/sync_run_context.dart';

/// Why a background run ended. Logged, and returned for tests.
enum BackgroundSyncOutcome {
  /// No signed-in rep, so nothing is queued and there is no token to send with.
  noSession,
  offline,
  nothingQueued,
  sent,

  /// The OS budget ran out mid-drain. Every outbox persists its transitions,
  /// so the next run — or the next app open — resumes where this stopped.
  outOfTime,
  failed,
}

/// One background-worker run: send whatever is queued, then stop.
///
/// The best-effort companion to [SyncEngine] (`docs/blueprint/sync-architecture.md`
/// §8). Neither Android nor iOS promises when — or whether — this runs, so
/// nothing may depend on it: reconnect and resume in the foreground remain the
/// reliable path. What it adds is that a rep who captured a check-out in a
/// dead zone and pocketed the phone has it delivered without reopening the app.
///
/// Every dependency is injected so the platform glue stays thin and this stays
/// testable without a device.
class BackgroundSyncRunner {
  const BackgroundSyncRunner({
    required UnsentWorkService unsentWork,
    required ConnectivityService connectivity,
    required Future<bool> Function() restoreSession,
    required AppLogger logger,
  })  : _unsentWork = unsentWork,
        _connectivity = connectivity,
        _restoreSession = restoreSession,
        _logger = logger;

  final UnsentWorkService _unsentWork;
  final ConnectivityService _connectivity;

  /// Answers whether a rep is signed in, promoting the cached session first if
  /// this isolate has not (no network — the same restore boot does). A
  /// callback because the session lives in the authentication feature, which
  /// `core/` must not import.
  final Future<bool> Function() _restoreSession;
  final AppLogger _logger;

  Future<BackgroundSyncOutcome> run({required Duration budget}) async {
    final outcome = await _run(budget);
    // The outcome only (`docs/skills/security.md` §10).
    _logger.info('sync.background', fields: {'outcome': outcome.name});
    return outcome;
  }

  Future<BackgroundSyncOutcome> _run(Duration budget) async {
    try {
      if (!await _restoreSession()) return BackgroundSyncOutcome.noSession;

      // Cheap local read before any network: most runs find nothing.
      if (await _unsentWork.countSendable() == 0) {
        return BackgroundSyncOutcome.nothingQueued;
      }

      // Real reachability (ADR-005). A fresh isolate's service starts
      // pessimistic, so it is probed here rather than read.
      final status = await _connectivity.refresh();
      if (status != ConnectivityStatus.online) {
        return BackgroundSyncOutcome.offline;
      }

      await SyncRunContext.withBudget(
          budget, () => _unsentWork.sendAll().timeout(budget));
      return BackgroundSyncOutcome.sent;
    } on TimeoutException {
      return BackgroundSyncOutcome.outOfTime;
    } catch (e, stack) {
      _logger.error('sync.background.failed', error: e, stackTrace: stack);
      return BackgroundSyncOutcome.failed;
    }
  }
}
