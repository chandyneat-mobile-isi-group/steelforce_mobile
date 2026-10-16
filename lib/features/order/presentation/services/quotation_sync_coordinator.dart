import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';
import 'package:steelforce/features/order/domain/services/sync_queue_processor.dart';

/// Decides *when* quotations sync to the Admin backend, so the rep never has
/// to remember to press anything.
///
/// It used to be manual-only: a queued quotation sat on the device until the
/// rep tapped "Sync Now" or accepted a reconnect snackbar, and an administrator
/// learned of it whenever that happened to be. Now a push runs when:
///
/// * a quotation is queued, or a queued one's retry backoff comes due;
/// * the device regains **real** reachability (ADR-005, not interface-up);
/// * the app returns to the foreground;
/// * a slow periodic sweep fires (reads review decisions back).
///
/// Review read-back is throttled to [reviewInterval] — the rep's mobile data is
/// metered and an administrator's decision is not urgent to the second — but
/// reconnect and resume always read, since that is when the rep looks.
///
/// Runs are coalesced and never overlap. Nothing here navigates or interrupts.
class QuotationSyncCoordinator with WidgetsBindingObserver {
  QuotationSyncCoordinator({
    required SyncQueueProcessor processor,
    required SyncQueueRepository queue,
    required ConnectivityService connectivity,
    Future<void> Function()? sendFirst,
    this.sweepInterval = const Duration(minutes: 5),
    this.reviewInterval = const Duration(minutes: 15),
    this.coalesceDelay = const Duration(milliseconds: 800),
  })  : _processor = processor,
        _queue = queue,
        _connectivity = connectivity,
        _sendFirst = sendFirst;

  final SyncQueueProcessor _processor;
  final SyncQueueRepository _queue;
  final ConnectivityService _connectivity;

  /// Sends what the server must have before any quotation — the check-in of
  /// the stop it was taken at. Wired in the composition root; a failure there
  /// never holds a quotation back.
  final Future<void> Function()? _sendFirst;

  final Duration sweepInterval;
  final Duration reviewInterval;

  /// Folds a burst of triggers (a save emits the queue several times) into
  /// one run.
  final Duration coalesceDelay;

  final StreamController<bool> _running = StreamController<bool>.broadcast();
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  StreamSubscription<List<SyncQueueItem>>? _queueSub;
  Timer? _sweep;
  Timer? _retryTimer;
  Timer? _coalesce;
  bool _pendingReviews = false;
  bool _started = false;
  bool _busy = false;
  bool _rerun = false;
  DateTime? _lastReviewAt;

  /// Completes when the run in progress does, so [runNow] can wait for it.
  Future<void>? _inFlight;

  /// True while a run is in progress, for the Sync Center spinner.
  Stream<bool> get running => _running.stream;
  bool get isRunning => _busy;

  /// Idempotent. Called when the signed-in shell mounts.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivity.changes.listen((status) {
      if (status == ConnectivityStatus.online) _schedule(reviews: true);
    });
    _queueSub = _queue.watchQueue().listen(_onQueue);
    _sweep = Timer.periodic(sweepInterval, (_) => _schedule());
    _schedule(reviews: true);
  }

  /// Idempotent. Called when the signed-in shell goes away (sign-out).
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _connectivitySub?.cancel();
    await _queueSub?.cancel();
    _sweep?.cancel();
    _retryTimer?.cancel();
    _coalesce?.cancel();
    _connectivitySub = null;
    _queueSub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule(reviews: true);
  }

  /// Runs now and completes when the run does. For the rep's explicit
  /// "Sync Now" / "Retry", which reads reviews back, and for the sync engine
  /// ([reviews] false), which needs quotations sent before the visits that
  /// follow them in its queue.
  ///
  /// A run already in progress is waited for, then followed by a fresh one, so
  /// the caller is only released once everything queued before the call has
  /// had a full pass.
  Future<void> runNow({bool reviews = true}) async {
    _coalesce?.cancel();
    final running = _inFlight;
    if (_busy && running != null) await running;
    await _run(forceReviews: reviews);
  }

  void _onQueue(List<SyncQueueItem> items) {
    final now = DateTime.now();
    DateTime? nextDue;
    var readyNow = false;
    for (final item in items) {
      if (item.status != QuotationSyncStatus.pendingSync) continue;
      final due = item.nextRetryAt;
      if (due == null || !due.isAfter(now)) {
        readyNow = true;
      } else if (nextDue == null || due.isBefore(nextDue)) {
        nextDue = due;
      }
    }
    if (readyNow) _schedule();

    _retryTimer?.cancel();
    if (nextDue != null) {
      _retryTimer = Timer(nextDue.difference(now), _schedule);
    }
  }

  void _schedule({bool reviews = false}) {
    if (!_started) return;
    _pendingReviews = _pendingReviews || reviews;
    _coalesce?.cancel();
    _coalesce = Timer(coalesceDelay, () {
      final forceReviews = _pendingReviews;
      _pendingReviews = false;
      unawaited(_run(forceReviews: forceReviews));
    });
  }

  Future<void> _run({required bool forceReviews}) async {
    if (_busy) {
      // A trigger landed mid-run; go again once this one finishes.
      _rerun = true;
      _pendingReviews = _pendingReviews || forceReviews;
      return;
    }
    if (!_connectivity.isOnline) return;
    _busy = true;
    final done = Completer<void>();
    _inFlight = done.future;
    _emitRunning(true);
    try {
      final sendFirst = _sendFirst;
      if (sendFirst != null) {
        try {
          await sendFirst();
        } catch (_) {
          // The quotations still go; the check-ins are retried by their own
          // queue.
        }
      }
      await _processor.processAll();
      final due = _lastReviewAt == null ||
          DateTime.now().difference(_lastReviewAt!) >= reviewInterval;
      if (forceReviews || due) {
        _lastReviewAt = DateTime.now();
        await _processor.refreshReviews();
      }
    } catch (_) {
      // Every state transition the processor makes is already persisted; a
      // failure here only means this run ends early. The next trigger resumes.
    } finally {
      _busy = false;
      _emitRunning(false);
      done.complete();
    }
    if (_rerun && _started) {
      _rerun = false;
      _schedule();
    }
  }

  void _emitRunning(bool value) {
    if (!_running.isClosed) _running.add(value);
  }
}
