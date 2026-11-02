import 'dart:async';

import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';

/// One kind of server data the rep needs on the device to work offline —
/// depots, routes, the catalog, visit plans, their profile.
///
/// The pull half of [UnsentWorkSource]: each feature keeps its own pull and
/// local copy, and this is only the hook that runs it.
abstract interface class OfflineDataSource {
  /// For logs only; never user-visible.
  String get name;

  /// Pulls the latest copy onto the device. Offline it fails fast and keeps
  /// what is already there.
  Future<void> refresh();
}

/// An [OfflineDataSource] that runs [onRefresh] — for a feature whose pull is
/// already one call.
class CallbackOfflineDataSource implements OfflineDataSource {
  const CallbackOfflineDataSource(this.name, this.onRefresh);

  @override
  final String name;
  final Future<void> Function() onRefresh;

  @override
  Future<void> refresh() => onRefresh();
}

/// Fills the device with what the rep needs to keep working offline, without
/// waiting for them to open each screen (ADR-002).
///
/// A rep may open the app once, see Home, and drive out of signal. Every
/// feature used to pull only when its own screen opened, so that rep had
/// depots but no plans, or plans but no catalog. This runs every
/// [OfflineDataSource] when the signed-in shell starts and again whenever
/// real reachability returns (ADR-005).
///
/// Sources run side by side and fail alone: one endpoint down never costs the
/// others. Runs never overlap, and a run within [minInterval] of the last one
/// that finished is skipped — a flapping connection must not re-pull the whole
/// catalog every few seconds.
class OfflineDataPrefetcher {
  OfflineDataPrefetcher({
    required List<OfflineDataSource> Function() sources,
    required ConnectivityService connectivity,
    required AppLogger logger,
    required bool Function() isAuthenticated,
    this.minInterval = const Duration(minutes: 5),
    DateTime Function() now = DateTime.now,
  })  : _sources = sources,
        _connectivity = connectivity,
        _logger = logger,
        _isAuthenticated = isAuthenticated,
        _now = now;

  final List<OfflineDataSource> Function() _sources;
  final ConnectivityService _connectivity;
  final AppLogger _logger;
  final bool Function() _isAuthenticated;
  final DateTime Function() _now;
  final Duration minInterval;

  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  Future<void>? _inFlight;
  DateTime? _lastRun;

  /// Idempotent. Called when the signed-in shell mounts: pulls now, and again
  /// on every return to real reachability.
  void start() {
    if (_connectivitySub != null) return;
    _connectivitySub = _connectivity.changes.listen((status) {
      if (status == ConnectivityStatus.online) unawaited(run());
    });
    unawaited(run());
  }

  /// Idempotent. Called when the signed-in shell goes away.
  Future<void> stop() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    // The shell can disappear while a pull is persisting a master-data page.
    // Sign-out waits for it before clearing the same database.
    await _inFlight;
  }

  /// Runs every source once. A call while a run is in progress joins it.
  /// [force] ignores [minInterval] — for an explicit "refresh everything".
  Future<void> run({bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (!_isAuthenticated()) return Future.value();
    final last = _lastRun;
    if (!force && last != null && _now().difference(last) < minInterval) {
      return Future.value();
    }
    final run = _runAll().whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<void> _runAll() async {
    // The cached status can be a stale `offline` from a probe minutes ago;
    // re-probe before giving up on the run.
    final online = _connectivity.isOnline ||
        await _connectivity.refresh() == ConnectivityStatus.online;
    if (!online) return;
    final sources = _sources();
    _logger.info('offline_data.prefetch.start',
        fields: {'sources': sources.length});
    final results = await Future.wait(sources.map(_runOne));
    _lastRun = _now();
    _logger.info('offline_data.prefetch.done', fields: {
      'ok': results.where((ok) => ok).length,
      'failed': results.where((ok) => !ok).length,
    });
  }

  Future<bool> _runOne(OfflineDataSource source) async {
    try {
      await source.refresh();
      return true;
    } on Object catch (e) {
      // Only the source and the error type: a message can carry data.
      _logger.warning('offline_data.prefetch.source_failed',
          fields: {'source': source.name, 'error': e.runtimeType.toString()});
      return false;
    }
  }
}
