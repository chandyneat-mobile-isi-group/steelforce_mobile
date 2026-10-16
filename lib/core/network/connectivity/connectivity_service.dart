import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Application-wide connectivity state.
///
/// [online] means **the app can actually reach its API**, not merely that the OS
/// reports a network interface — see [ConnectivityService].
enum ConnectivityStatus { online, offline }

/// Confirms real internet reachability, separate from interface-up state.
///
/// Extracted as a seam so [ConnectivityServiceImpl] is testable without a
/// network (`docs/skills/ai-engineering-playbook.md` §7.6: a test that mocks away the
/// thing under test is worse than no test — here the probe is a collaborator,
/// not the logic being verified).
abstract interface class ReachabilityProbe {
  Future<bool> isReachable();
}

/// Probes the app's **own** API ([AppConfig.apiBaseUrl]).
///
/// ADR-005 is explicit that the probe must target our own infrastructure rather
/// than a third-party endpoint, so "reachable" means "reachable enough to sync"
/// — a third-party host being down must never make the app think it is offline.
///
/// `docs/skills/security.md` §6 requires a timeout and a defined retry policy on every
/// network call: this issues a single bounded-timeout request and never retries
/// (the caller re-probes on the next connectivity event; retry/backoff is the
/// sync engine's job, per `docs/blueprint/sync-architecture.md` §4).
class HttpReachabilityProbe implements ReachabilityProbe {
  HttpReachabilityProbe({
    required Dio dio,
    required AppLogger logger,
    Duration timeout = const Duration(seconds: 5),
  })  : _dio = dio,
        _logger = logger,
        _timeout = timeout {
    // Bounds the connect phase, which the per-request `Options` cannot: Dio
    // exposes `connectTimeout` only on `BaseOptions`, and defaults it to null,
    // meaning *no limit*.
    //
    // Without this, a host that blackholes SYN packets — a dead tunnel, or a
    // firewall that drops rather than refuses — hung this probe indefinitely
    // instead of for [timeout]. That is not a theoretical concern: bootstrap
    // awaited the probe before `runApp`, so the hang meant the app never
    // rendered a first frame and simply sat on the launch screen.
    //
    // `??=` so a caller supplying a pre-configured client keeps its own value.
    _dio.options.connectTimeout ??= timeout;
  }

  final Dio _dio;
  final AppLogger _logger;
  final Duration _timeout;

  @override
  Future<bool> isReachable() async {
    try {
      final response = await _dio
          .head<void>(
            AppConfig.apiBaseUrl,
            options: Options(
              // These two only start counting once a connection exists, so
              // they cannot bound the connect phase. `connectTimeout` covers
              // that and lives on `BaseOptions` rather than `Options` — which
              // is exactly how it came to be missing; it is set in the
              // constructor.
              sendTimeout: _timeout,
              receiveTimeout: _timeout,
              // Any HTTP answer proves the network path works. A 401/404 still
              // means we reached the gateway, which is what "online" must mean
              // here — the alternative (requiring 2xx) would report offline
              // whenever the token is stale, and ADR-002 forbids coupling
              // connectivity to auth.
              validateStatus: (_) => true,
            ),
          )
          // The outer, unconditional bound. Dio's own timeouts are enforced by
          // the HTTP adapter, so they are only as good as the adapter in play
          // — a custom or mocked one enforces nothing, and this probe sits on
          // the path to first frame. A wall-clock timeout here makes "the
          // probe always answers within [_timeout]" a property of this class
          // rather than a hope about its transport.
          .timeout(_timeout);

      return response.statusCode != null;
    } on TimeoutException {
      _logger.debug('connectivity.probe_failed', fields: {'reason': 'timeout'});
      return false;
    } on DioException catch (e) {
      // §10: log the failure type only — never the request or response body.
      _logger
          .debug('connectivity.probe_failed', fields: {'reason': e.type.name});
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// The single source of truth for connectivity across the app (ADR-005).
///
/// Every consumer — the UI status pill (`docs/blueprint/offline-architecture.md` §5) and the sync
/// drain trigger (`docs/blueprint/sync-architecture.md` §9) — subscribes here, so the pill and
/// the sync engine can never disagree. **No UI, bloc, repository or DAO may call
/// `connectivity_plus` directly** (ADR-005 §3).
abstract interface class ConnectivityService {
  /// Last known state, readable synchronously so guards and the sync
  /// coordinator don't have to await (mirrors the `SessionManager` pattern in
  /// `docs/blueprint/offline-architecture.md` §2.6).
  ConnectivityStatus get status;

  bool get isOnline;

  /// Broadcast stream of **distinct** state changes — never emits the same
  /// state twice in a row, so a flapping radio can't trigger repeated drains.
  Stream<ConnectivityStatus> get changes;

  /// Begins monitoring. Idempotent: calling twice does not create a second
  /// listener (ADR-005: "prevent duplicate listeners").
  Future<void> start();

  /// Forces an immediate reachability re-check, e.g. on foreground resume
  /// (`docs/blueprint/sync-architecture.md` §9).
  Future<ConnectivityStatus> refresh();

  Future<void> dispose();
}

class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl({
    required Connectivity connectivity,
    required ReachabilityProbe probe,
    required AppLogger logger,
    Duration debounce = const Duration(milliseconds: 500),
  })  : _connectivity = connectivity,
        _probe = probe,
        _logger = logger,
        _debounce = debounce;

  final Connectivity _connectivity;
  final ReachabilityProbe _probe;
  final AppLogger _logger;
  final Duration _debounce;

  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;

  /// Guards against overlapping probes when events arrive faster than the probe
  /// resolves — without this, a flapping radio queues probes indefinitely.
  bool _probing = false;

  /// Starts pessimistic: nothing is "online" until a probe proves it.
  ConnectivityStatus _status = ConnectivityStatus.offline;

  @override
  ConnectivityStatus get status => _status;

  @override
  bool get isOnline => _status == ConnectivityStatus.online;

  @override
  Stream<ConnectivityStatus> get changes => _controller.stream;

  @override
  Future<void> start() async {
    // Idempotent (ADR-005: no duplicate listeners).
    if (_subscription != null) return;

    _subscription = _connectivity.onConnectivityChanged.listen(
      _onInterfaceChanged,
      // ADR-005 §4: this service reports state, it never throws to signal
      // offline. A plugin error means "cannot confirm reachability".
      onError: (Object e) {
        _logger.warning(
          'connectivity.stream_error',
          fields: {'reason': e.runtimeType.toString()},
        );
        _publish(ConnectivityStatus.offline);
      },
    );

    await refresh();
  }

  void _onInterfaceChanged(List<ConnectivityResult> results) {
    // Cheap first filter (ADR-005 §1): if the radio is plainly off there is no
    // point spending battery on a probe — go offline immediately.
    if (_isInterfaceDown(results)) {
      _debounceTimer?.cancel();
      _publish(ConnectivityStatus.offline);
      return;
    }

    // Interface up proves nothing (captive portal, no data plan), so debounce
    // then confirm with a real probe (ADR-005 §2).
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(refresh()));
  }

  bool _isInterfaceDown(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  @override
  Future<ConnectivityStatus> refresh() async {
    if (_probing) return _status;
    _probing = true;
    try {
      final results = await _connectivity.checkConnectivity();
      if (_isInterfaceDown(results)) {
        _publish(ConnectivityStatus.offline);
        return _status;
      }
      final reachable = await _probe.isReachable();
      _publish(
        reachable ? ConnectivityStatus.online : ConnectivityStatus.offline,
      );
      return _status;
    } finally {
      _probing = false;
    }
  }

  /// Emits only on an actual transition, so `changes` stays distinct.
  void _publish(ConnectivityStatus next) {
    if (_status == next) return;
    _status = next;
    _logger.info('connectivity.changed', fields: {'status': next.name});
    if (!_controller.isClosed) _controller.add(next);
  }

  @override
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
