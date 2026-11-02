import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/network/work_mode/mode_aware_connectivity_service.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/shell/presentation/bloc/work_mode_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode_button.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode_confirm_dialog.dart';

/// Offers the right work mode when the connection changes under the rep.
///
/// The internet drops while in Online Mode: once the loss has held for
/// [settle], the Offline Mode dialog opens by itself — say yes and the
/// Online / Offline button switches with it. The internet comes back while
/// in Offline Mode: the Online Mode dialog opens, since nothing is sent
/// until the rep switches back. Asked once per drop and once per return; a
/// connection that flickers back within [settle] asks nothing.
///
/// Always a question, never a silent switch: the mode is the rep's choice
/// (`WorkModeService`), and they may have a reason to stay.
class WorkModeAutoPrompt extends StatefulWidget {
  const WorkModeAutoPrompt({
    super.key,
    required this.child,
    this.deviceChanges,
    this.deviceStatus,
    this.cubit,
    this.enabled,
    this.settle = const Duration(seconds: 3),
  });

  final Widget child;

  /// The device's own reachability; defaults to the app's.
  final Stream<ConnectivityStatus>? deviceChanges;
  final ConnectivityStatus Function()? deviceStatus;
  final WorkModeCubit? cubit;

  /// Whether to ask at all; defaults to "signed in" — a guest has nothing
  /// to send.
  final bool Function()? enabled;
  final Duration settle;

  @override
  State<WorkModeAutoPrompt> createState() => _WorkModeAutoPromptState();
}

class _WorkModeAutoPromptState extends State<WorkModeAutoPrompt> {
  StreamSubscription<ConnectivityStatus>? _sub;
  late final ConnectivityStatus Function() _deviceStatus;
  late final WorkModeCubit _cubit;
  Timer? _settle;

  /// The device status already asked about, so one drop asks once.
  ConnectivityStatus? _askedFor;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? sl<WorkModeCubit>();
    final service = sl.isRegistered<ConnectivityService>()
        ? sl<ConnectivityService>()
        : null;
    final modeAware = service is ModeAwareConnectivityService ? service : null;
    _deviceStatus = widget.deviceStatus ??
        () => modeAware?.deviceStatus ?? ConnectivityStatus.online;
    _sub = (widget.deviceChanges ?? modeAware?.deviceChanges)
        ?.listen(_onDeviceChange);
  }

  void _onDeviceChange(ConnectivityStatus status) {
    _settle?.cancel();
    // A flip back to the status already asked about re-arms the next one.
    if (status != _askedFor) _askedFor = null;
    _settle = Timer(widget.settle, _maybeAsk);
  }

  Future<void> _maybeAsk() async {
    if (!mounted || !_enabled()) return;
    final status = _deviceStatus();
    if (status == _askedFor) return;
    final mode = _cubit.state.mode;
    final WorkMode target;
    final WorkModePrompt prompt;
    if (status == ConnectivityStatus.offline && mode == WorkMode.online) {
      target = WorkMode.offline;
      prompt = WorkModePrompt.connectionLost;
    } else if (status == ConnectivityStatus.online &&
        mode == WorkMode.offline) {
      target = WorkMode.online;
      prompt = WorkModePrompt.connectionBack;
    } else {
      return;
    }
    _askedFor = status;
    await requestWorkModeSwitch(context, target, cubit: _cubit, prompt: prompt);
  }

  bool _enabled() {
    final enabled = widget.enabled;
    if (enabled != null) return enabled();
    return sl.isRegistered<SessionManager>() &&
        sl<SessionManager>().canCallProtectedApi;
  }

  @override
  void dispose() {
    _settle?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
