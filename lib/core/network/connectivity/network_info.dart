import 'package:connectivity_plus/connectivity_plus.dart';

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
