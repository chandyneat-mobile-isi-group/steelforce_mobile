import 'dart:async';

import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';

/// The [ConnectivityService] the app consumes: the device's real reachability
/// (ADR-005), reported as offline while the rep has chosen [WorkMode.offline].
///
/// Composing the two here, rather than teaching every consumer about the mode,
/// is what makes the choice hold everywhere at once: the sync engine, the
/// background worker, the depot and route pulls and the offline banner all
/// already treat "offline" as "work from the device, send nothing" (ADR-002).
/// A consumer added later inherits the mode without knowing it exists.
///
/// The two inputs stay separate: [deviceStatus] is the radio and the API's
/// answer, never the rep's choice, so the mode switch can say "no connection"
/// honestly when the rep asks to go online with no signal.
class ModeAwareConnectivityService implements ConnectivityService {
  ModeAwareConnectivityService({
    required ConnectivityService device,
    required WorkModeService workMode,
  })  : _device = device,
        _workMode = workMode;

  final ConnectivityService _device;
  final WorkModeService _workMode;

  final StreamController<ConnectivityStatus> _changes =
      StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription<ConnectivityStatus>? _deviceSub;
  StreamSubscription<WorkMode>? _modeSub;
  ConnectivityStatus? _last;

  /// Real reachability, regardless of the chosen mode.
  ConnectivityStatus get deviceStatus => _device.status;

  /// Changes of [deviceStatus] — the signal itself, which the effective
  /// [changes] hide while Offline Mode is on. What lets the app offer
  /// Offline Mode when the connection drops, and Online when it is back.
  Stream<ConnectivityStatus> get deviceChanges => _device.changes;

  @override
  ConnectivityStatus get status =>
      _workMode.isOffline ? ConnectivityStatus.offline : _device.status;

  @override
  bool get isOnline => status == ConnectivityStatus.online;

  @override
  Stream<ConnectivityStatus> get changes {
    _listen();
    return _changes.stream;
  }

  /// Subscribed on first use rather than in [start], so a consumer that
  /// listens before startup (the sync engine is built lazily) still hears the
  /// mode switch.
  void _listen() {
    if (_deviceSub != null) return;
    _last = status;
    _deviceSub = _device.changes.listen((_) => _publish());
    _modeSub = _workMode.changes.listen((_) => _publish());
  }

  void _publish() {
    final next = status;
    if (next == _last) return;
    _last = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  @override
  Future<void> start() async {
    _listen();
    await _device.start();
  }

  /// Still probes the device in offline mode, so [deviceStatus] stays current
  /// for the switch back; the answer reported is the effective one.
  @override
  Future<ConnectivityStatus> refresh() async {
    await _device.refresh();
    return status;
  }

  @override
  Future<void> dispose() async {
    await _deviceSub?.cancel();
    await _modeSub?.cancel();
    await _changes.close();
    await _device.dispose();
  }
}
