import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';

// One [ConnectivityStatus] for the whole app. This file used to declare its own
// identical enum, so a widget importing both libraries could not name the type
// at all. Re-exported so the cubit's consumers keep their single import.
export 'package:steelforce/core/network/connectivity/connectivity_service.dart'
    show ConnectivityStatus;

/// Observes device connectivity and nothing more. Per the offline-first spec it
/// **never navigates, opens screens, or interrupts** — the UI decides what to
/// do with a status change (show a banner, offer a "Sync Now" snackbar, …).
///
/// Starts optimistic (`online`) so the app never flashes an offline banner
/// before the first real reading arrives.
class ConnectivityCubit extends Cubit<ConnectivityStatus> {
  ConnectivityCubit(this._connectivity) : super(ConnectivityStatus.online) {
    _subscription =
        _connectivity.onConnectivityChanged.listen(_emitFromResults);
    _init();
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  bool get isOnline => state == ConnectivityStatus.online;

  Future<void> _init() async {
    _emitFromResults(await _connectivity.checkConnectivity());
  }

  void _emitFromResults(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    emit(online ? ConnectivityStatus.online : ConnectivityStatus.offline);
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
