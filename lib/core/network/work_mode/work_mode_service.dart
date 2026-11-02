import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/database/hive/preference_keys.dart';

/// How the rep has chosen to work. A choice, not a measurement: the device's
/// actual reachability is [ConnectivityService]'s business, and a good signal
/// never overrides [offline].
enum WorkMode {
  /// Screens still open from the device (ADR-002); the app also refreshes from
  /// the server and sends saved work automatically.
  online,

  /// Screens open from the device and nothing goes to the server: no
  /// background refresh, no automatic or manual sync. Saved work stays queued
  /// until the rep switches back. For a weak or metered connection, where
  /// every request would otherwise wait out a timeout.
  offline;

  static WorkMode fromStorage(Object? value) =>
      value == offline.name ? offline : online;
}

/// The one source of truth for [WorkMode], persisted across restarts.
///
/// Everything that must respect the mode reads it from here — the
/// mode-aware connectivity (so sync and pull stop) and the API client's
/// request guard (so no screen can reach the server around it).
abstract interface class WorkModeService {
  WorkMode get mode;

  bool get isOffline;

  /// Distinct changes only.
  Stream<WorkMode> get changes;

  /// Persists, then publishes. Throws if the choice could not be saved, and
  /// the previous mode stays in force — a switch that would not survive a
  /// restart is not made at all.
  Future<void> setMode(WorkMode mode);
}

/// Hive-backed: a non-sensitive preference (`security.md` §2), readable
/// synchronously so request guards never await.
class HiveWorkModeService implements WorkModeService {
  HiveWorkModeService(this._box)
      : _mode = WorkMode.fromStorage(_box.get(PreferenceKeys.kWorkMode));

  final Box<dynamic> _box;
  final StreamController<WorkMode> _changes =
      StreamController<WorkMode>.broadcast();
  WorkMode _mode;

  @override
  WorkMode get mode => _mode;

  @override
  bool get isOffline => _mode == WorkMode.offline;

  @override
  Stream<WorkMode> get changes => _changes.stream;

  @override
  Future<void> setMode(WorkMode mode) async {
    if (mode == _mode) return;
    await _box.put(PreferenceKeys.kWorkMode, mode.name);
    _mode = mode;
    if (!_changes.isClosed) _changes.add(mode);
  }
}
