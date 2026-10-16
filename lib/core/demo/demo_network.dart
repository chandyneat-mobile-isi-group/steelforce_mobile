import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/utils/mock_latency.dart';

/// The simulated network of a demo build (`USE_MOCK_DATA=true`).
///
/// A demo has no backend, but it still has to show both halves of an
/// offline-first app: work syncing, and work queuing while the rep has no
/// signal. So the "network" is a switch the presenter flips from the DEMO
/// badge, and everything that would observe a real network observes this
/// instead:
///
/// * [DemoConnectivity] and [DemoReachabilityProbe] feed the real
///   `ConnectivityService`, `ConnectivityCubit` and `NetworkInfo`, so the
///   status pill and the sync drain trigger react exactly as they would to a
///   dropped signal.
/// * Every demo remote data source calls [roundTrip] first, which fails with
///   the same `ApiError(network)` a real connection error maps to — so the
///   repositories' real offline paths run, not a demo imitation of them.
///
/// TODO(release-gate): demo-only. Registered only when
/// `DataSourceMode.useMocks` is true; a live build never constructs it.
class DemoNetwork {
  DemoNetwork({bool online = true}) : online = ValueNotifier<bool>(online);

  /// True while the simulated backend is reachable.
  final ValueNotifier<bool> online;

  bool get isOnline => online.value;

  void setOnline(bool value) => online.value = value;

  void toggle() => online.value = !online.value;

  /// Simulates one request to the backend: the configured latency, then a
  /// network failure if the presenter has switched the demo offline.
  ///
  /// Checked after the delay as well as before it, so flipping offline
  /// mid-request fails that request — as a real dropped connection would.
  Future<void> roundTrip() async {
    _throwIfOffline();
    await MockLatency.tick();
    _throwIfOffline();
  }

  void _throwIfOffline() {
    if (!online.value) {
      throw const ApiException(ApiError(code: ApiErrorCodes.network));
    }
  }
}

/// Stands in for the `connectivity_plus` plugin so the radio state follows
/// [DemoNetwork] rather than the device's real interface.
class DemoConnectivity implements Connectivity {
  DemoConnectivity(this._network) {
    _network.online.addListener(_emit);
  }

  final DemoNetwork _network;
  final StreamController<List<ConnectivityResult>> _changes =
      StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> get _current => _network.isOnline
      ? const [ConnectivityResult.wifi]
      : const [ConnectivityResult.none];

  void _emit() => _changes.add(_current);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;
}

/// Answers the ADR-005 reachability probe from [DemoNetwork], so a demo build
/// never opens a socket to find out whether it is online.
class DemoReachabilityProbe implements ReachabilityProbe {
  const DemoReachabilityProbe(this._network);

  final DemoNetwork _network;

  @override
  Future<bool> isReachable() async => _network.isOnline;
}
