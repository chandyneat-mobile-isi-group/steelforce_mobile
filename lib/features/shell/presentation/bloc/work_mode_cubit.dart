import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';

/// What a [WorkModeCubit.switchTo] call did, for the message the rep sees.
enum WorkModeSwitchResult {
  /// Now offline: saved work stays queued on the device.
  offline,

  /// Now online, and the API answered: saved work is being sent.
  online,

  /// Now online, but the device cannot reach the server yet. Saved work sends
  /// when it can — this is not "synced".
  onlineNoConnection,

  /// Already in that mode, or a switch was already running (repeat tap).
  ignored,

  /// The choice could not be saved; the previous mode is still in force.
  failed,
}

class WorkModeState extends Equatable {
  const WorkModeState({required this.mode, this.switching = false});

  final WorkMode mode;

  /// True while a switch is being applied — the control is disabled.
  final bool switching;

  bool get isOffline => mode == WorkMode.offline;

  @override
  List<Object?> get props => [mode, switching];
}

/// Drives the shell's Online / Offline control.
///
/// The mode itself lives in [WorkModeService] — this cubit only applies a
/// switch safely and reflects the service, so a second screen showing the
/// mode can never disagree with the first.
class WorkModeCubit extends Cubit<WorkModeState> {
  WorkModeCubit({
    required WorkModeService workMode,
    required Future<void> Function() waitForSyncIdle,
    required Future<int> Function() countUnsent,
    required Future<ConnectivityStatus> Function() refreshConnectivity,
  })  : _workMode = workMode,
        _waitForSyncIdle = waitForSyncIdle,
        _countUnsent = countUnsent,
        _refreshConnectivity = refreshConnectivity,
        super(WorkModeState(mode: workMode.mode)) {
    _sub = _workMode.changes.listen((mode) {
      if (!isClosed) {
        emit(WorkModeState(mode: mode, switching: state.switching));
      }
    });
  }

  final WorkModeService _workMode;
  late final StreamSubscription<WorkMode> _sub;
  final Future<void> Function() _waitForSyncIdle;
  final Future<int> Function() _countUnsent;
  final Future<ConnectivityStatus> Function() _refreshConnectivity;

  /// Work saved on the device and not yet on the server, for the
  /// confirmation dialog. Switching never touches it either way.
  Future<int> unsentCount() async {
    try {
      return await _countUnsent();
    } catch (_) {
      // The dialog must still open; it simply cannot quote a number.
      return 0;
    }
  }

  Future<WorkModeSwitchResult> switchTo(WorkMode target) async {
    if (state.switching || target == state.mode) {
      return WorkModeSwitchResult.ignored;
    }
    emit(WorkModeState(mode: state.mode, switching: true));
    try {
      if (target == WorkMode.offline) {
        // Let a send already in progress finish and record its result.
        await _waitForSyncIdle();
      }
      await _workMode.setMode(target);
    } catch (_) {
      // Nothing was changed: [WorkModeService.setMode] publishes only after
      // the choice is saved.
      if (!isClosed) {
        emit(WorkModeState(mode: _workMode.mode));
      }
      return WorkModeSwitchResult.failed;
    }
    if (!isClosed) emit(WorkModeState(mode: _workMode.mode));
    if (target == WorkMode.offline) return WorkModeSwitchResult.offline;

    // Going online publishes the device's real reachability; if it is up,
    // the sync engine starts sending on that same change. Re-probe so the
    // message reflects now, not a snapshot from before the switch.
    final status = await _refreshConnectivity();
    return status == ConnectivityStatus.online
        ? WorkModeSwitchResult.online
        : WorkModeSwitchResult.onlineNoConnection;
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
