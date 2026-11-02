import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';

/// Thin abstraction over connectivity so repositories can fail fast when
/// offline without depending on a concrete plugin (keeps them testable).
abstract interface class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  const NetworkInfoImpl(this._connectivity);
  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

/// [NetworkInfo] by real reachability (ADR-005), not by the radio being on.
///
/// With Wi-Fi or data up but no internet behind it — a weak hotspot, a
/// captive network, a SIM out of credit — the radio check said "online", so
/// every read waited out its 15-35 s request timeout before falling back to
/// the device's copy. That was what made offline use slow. In order:
///
///  1. The rep chose Offline Mode → offline, at once; nothing is attempted.
///  2. No radio → offline, at once.
///  3. The last reachability probe succeeded → online, at once.
///  4. Otherwise one bounded probe (at most 5 s) decides — and an "offline"
///     answer is trusted for [_recheckAfter], so a screen making several
///     calls does not probe each time.
class ReachableNetworkInfo implements NetworkInfo {
  ReachableNetworkInfo({
    required Connectivity connectivity,
    required ConnectivityService reachability,
    required WorkModeService workMode,
    DateTime Function() now = DateTime.now,
  })  : _connectivity = connectivity,
        _reachability = reachability,
        _workMode = workMode,
        _now = now;

  final Connectivity _connectivity;
  final ConnectivityService _reachability;
  final WorkModeService _workMode;
  final DateTime Function() _now;

  static const _recheckAfter = Duration(seconds: 15);
  DateTime? _lastOfflineProbe;

  @override
  Future<bool> get isConnected async {
    if (_workMode.isOffline) return false;
    final radios = await _connectivity.checkConnectivity();
    if (!radios.any((r) => r != ConnectivityResult.none)) return false;
    if (_reachability.isOnline) return true;

    final last = _lastOfflineProbe;
    if (last != null && _now().difference(last) < _recheckAfter) return false;
    final status = await _reachability.refresh();
    if (status == ConnectivityStatus.online) {
      _lastOfflineProbe = null;
      return true;
    }
    _lastOfflineProbe = _now();
    return false;
  }
}
