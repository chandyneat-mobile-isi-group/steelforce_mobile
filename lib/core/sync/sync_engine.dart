import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/session/unsent_work.dart';

/// Sends work saved offline to the server without the rep asking.
///
/// Every feature that keeps writes on the device until the server has them
/// (visit check-ins/outs and captures, ad hoc visits, quotations, …) already
/// registers an [UnsentWorkSource] so sign-out can refuse to wipe them. This
/// drains the same sources, so a feature that is safe at sign-out is also
/// synced automatically — one registration, two guarantees.
///
/// A drain runs when (`docs/blueprint/sync-architecture.md` §9):
///
/// * the signed-in shell starts — work left over from a killed process goes
///   out on the next launch (§7);
/// * the device regains **real** reachability (ADR-005, not interface-up);
/// * the app returns to the foreground;
/// * a feature calls [requestSync] after a local write;
/// * the retry timer fires while work is still outstanding.
///
/// The retry timer backs off (`base · 2^n + jitter`, capped — §4) for as long
/// as a drain makes no progress, so rows the server keeps refusing cannot turn
/// into a request loop on a metered, battery-bound device. Reconnect and resume
/// reset the backoff: those are the moments a stalled drain is likely to work.
///
/// Runs are coalesced and never overlap. Sources own their own idempotency and
/// failure bookkeeping; this class decides only *when* they run.
class SyncEngine with WidgetsBindingObserver {
  SyncEngine({
    required UnsentWorkService unsentWork,
    required ConnectivityService connectivity,
    required AppLogger logger,
    required bool Function() isAuthenticated,
    this.coalesceDelay = const Duration(seconds: 1),
    this.baseRetryDelay = const Duration(seconds: 30),
    this.maxRetryDelay = const Duration(minutes: 15),
    Random? random,
  })  : _unsentWork = unsentWork,
        _connectivity = connectivity,
        _logger = logger,
        _isAuthenticated = isAuthenticated,
        _random = random ?? Random();

  final UnsentWorkService _unsentWork;
  final ConnectivityService _connectivity;
  final AppLogger _logger;
  final bool Function() _isAuthenticated;

  final Random _random;

  /// Folds a burst of triggers (reconnect + resume arrive together) into one
  /// drain.
  final Duration coalesceDelay;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;

  final StreamController<bool> _running = StreamController<bool>.broadcast();
  final StreamController<SyncDrainReport> _reports =
      StreamController<SyncDrainReport>.broadcast();

  /// Set when real reachability returns; the next drain that has work to send
  /// reports itself as following a reconnect, which is the moment the rep is
  /// told their offline work went out.
  bool _reconnected = false;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  Timer? _coalesce;
  Timer? _retry;
  bool _started = false;
  bool _busy = false;
  bool _rerun = false;

  /// Completes when the drain in progress does, so [runNow] can wait for it.
  Future<void>? _inFlight;

  /// Consecutive drains that left work behind without sending any of it.
  int _stalled = 0;

  /// True between [start] and [stop] — the signed-in shell is mounted.
  bool get isStarted => _started;

  /// True while a drain is in progress.
  Stream<bool> get running => _running.stream;

  /// One event when a drain with work to send starts, and one when it ends —
  /// counts only. For telling the rep what happened to their offline work.
  Stream<SyncDrainReport> get reports => _reports.stream;
  bool get isRunning => _busy;

  /// Idempotent. Called when the signed-in shell mounts.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivity.changes.listen((status) {
      if (status == ConnectivityStatus.online) {
        _reconnected = true;
        _schedule(resetBackoff: true);
      }
    });
    _schedule(resetBackoff: true);
  }

  /// Idempotent. Called when the signed-in shell goes away.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _coalesce?.cancel();
    _retry?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The reachability snapshot can be minutes stale after a background spell;
    // re-probing publishes `online` if it changed, which schedules the drain.
    unawaited(_connectivity.refresh());
    _schedule(resetBackoff: true);
  }

  /// Asks for a drain soon. For a feature that has just saved something
  /// syncable locally; a no-op while offline beyond arming the next trigger.
  void requestSync() => _schedule(resetBackoff: true);

  /// Drains now and completes when the drain does. For an explicit "Sync now".
  ///
  /// If a drain is already running, waits for it and then drains again, so
  /// the caller is only released once work saved before the call has had a
  /// full pass — a background wake handing off to the app relies on that.
  ///
  /// Re-probes reachability first: the cached status can be a stale
  /// `offline` from a probe that failed minutes ago, and an explicit tap must
  /// not be silently ignored because of it. Answers false when it could not
  /// run (offline, or no signed-in rep), so the caller can say so.
  Future<bool> runNow() async {
    _coalesce?.cancel();
    final running = _inFlight;
    if (_busy && running != null) await running;
    if (!_started || !_isAuthenticated()) return false;
    if (await _connectivity.refresh() != ConnectivityStatus.online) {
      return false;
    }
    await _run();
    return true;
  }

  void _schedule({bool resetBackoff = false}) {
    if (!_started) return;
    if (resetBackoff) _stalled = 0;
    _coalesce?.cancel();
    _coalesce = Timer(coalesceDelay, () => unawaited(_run()));
  }

  Future<void> _run() async {
    if (!_started) return;
    if (_busy) {
      // A trigger landed mid-drain; go again once this one finishes.
      _rerun = true;
      return;
    }
    // A guest has nothing queued and no token to send it with.
    if (!_isAuthenticated()) return;
    if (!_connectivity.isOnline) return;

    _busy = true;
    final done = Completer<void>();
    _inFlight = done.future;
    _retry?.cancel();
    _emitRunning(true);
    var before = 0;
    var after = 0;
    var afterReconnect = false;
    try {
      // Sendable, not total: a row parked for the rep's decision must not
      // keep the retry timer firing forever.
      before = await _unsentWork.countSendable();
      afterReconnect = _reconnected;
      _reconnected = false;
      if (before > 0) {
        _emitReport(SyncDrainReport.started(
            waiting: before, afterReconnect: afterReconnect));
        await _unsentWork.sendAll();
        after = await _unsentWork.countSendable();
        // Counts only — never ids or payloads (`docs/skills/security.md` §10).
        _logger.info('sync.drain', fields: {'before': before, 'after': after});
      }
    } catch (e, stack) {
      // Sources persist their own state transitions, so a throw only ends this
      // drain early. The retry timer below picks it up again.
      _logger.error('sync.drain.failed', error: e, stackTrace: stack);
      after = before;
    } finally {
      _busy = false;
      _emitRunning(false);
      done.complete();
    }
    if (before > 0) {
      _emitReport(SyncDrainReport.finished(
        waiting: before,
        left: after,
        afterReconnect: afterReconnect,
      ));
    }

    if (!_started) return;
    if (_rerun) {
      _rerun = false;
      _schedule();
      return;
    }
    if (after > 0) {
      _stalled = after < before ? 0 : _stalled + 1;
      _armRetry();
    }
  }

  /// Schedules the next attempt while work remains: [baseRetryDelay] after a
  /// drain that made progress, doubling per stalled drain up to
  /// [maxRetryDelay], with up to 20% jitter so a fleet of devices regaining
  /// signal together does not retry in lockstep.
  void _armRetry() {
    _retry?.cancel();
    final exponent = min(_stalled, 10);
    final raw = baseRetryDelay.inMilliseconds * pow(2, exponent);
    final capped = min(raw.toInt(), maxRetryDelay.inMilliseconds);
    final jitter = (capped * 0.2 * _random.nextDouble()).toInt();
    _retry = Timer(Duration(milliseconds: capped + jitter), _schedule);
  }

  void _emitRunning(bool value) {
    if (!_running.isClosed) _running.add(value);
  }

  void _emitReport(SyncDrainReport report) {
    if (!_reports.isClosed) _reports.add(report);
  }
}

/// What one drain did, in counts — never ids or payloads.
class SyncDrainReport {
  const SyncDrainReport.started({
    required this.waiting,
    required this.afterReconnect,
  })  : finished = false,
        left = waiting;

  const SyncDrainReport.finished({
    required this.waiting,
    required this.left,
    required this.afterReconnect,
  }) : finished = true;

  final bool finished;

  /// Items that could be sent when the drain started.
  final int waiting;

  /// Still unsent when it ended. Includes anything saved meanwhile, so
  /// [sent] is a floor, not an exact count.
  final int left;

  /// The drain ran because the connection came back.
  final bool afterReconnect;

  int get sent => max(0, waiting - left);
}
