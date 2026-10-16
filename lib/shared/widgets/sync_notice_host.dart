import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Tells the rep what happened to work saved offline, app-wide:
///
/// * the connection drops → their work is safe on the phone and will go out
///   by itself;
/// * it comes back with work waiting → "syncing N items…", then what was sent
///   and what is still waiting.
///
/// The sending itself is the [SyncEngine]'s; this only reports it. Messages go
/// through [messengerKey] rather than `ScaffoldMessenger.of`, so they survive
/// the app restarting underneath them (language change, sign-out).
class SyncNoticeHost extends StatefulWidget {
  const SyncNoticeHost({
    super.key,
    required this.child,
    required this.messengerKey,
    this.engine,
    this.connectivity,
  });

  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  /// Null before sign-in wiring exists (tests, a guest boot): nothing is shown.
  final SyncEngine? engine;
  final ConnectivityService? connectivity;

  @override
  State<SyncNoticeHost> createState() => _SyncNoticeHostState();
}

class _SyncNoticeHostState extends State<SyncNoticeHost> {
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  StreamSubscription<SyncDrainReport>? _reportSub;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _offlineNotice;

  @override
  void initState() {
    super.initState();
    _connectivitySub = widget.connectivity?.changes.listen(_onConnectivity);
    _reportSub = widget.engine?.reports.listen(_onReport);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _reportSub?.cancel();
    super.dispose();
  }

  /// Only a signed-in rep has work that syncs; a guest is not told about it.
  bool get _signedIn => widget.engine?.isStarted ?? false;

  void _onConnectivity(ConnectivityStatus status) {
    if (!mounted || !_signedIn) return;
    if (status == ConnectivityStatus.online) {
      _offlineNotice?.close();
      _offlineNotice = null;
      return;
    }
    if (_offlineNotice != null) return;
    _offlineNotice = _show(
      icon: Icons.cloud_off_rounded,
      text: 'sync_notice.offline'.tr,
      duration: const Duration(seconds: 5),
    );
    _offlineNotice?.closed.then((_) => _offlineNotice = null);
  }

  void _onReport(SyncDrainReport report) {
    if (!mounted || !report.afterReconnect) return;
    final colors = context.appColors;

    if (!report.finished) {
      _show(
        icon: Icons.sync_rounded,
        text: 'sync_notice.syncing'.trParams({'count': report.waiting}),
        duration: const Duration(seconds: 10),
      );
      return;
    }

    if (report.sent > 0 && report.left == 0) {
      _show(
        icon: Icons.cloud_done_rounded,
        text: 'sync_notice.synced'.trParams({'count': report.sent}),
        background: colors.success,
      );
    } else if (report.sent > 0) {
      _show(
        icon: Icons.cloud_sync_rounded,
        text: 'sync_notice.partial'
            .trParams({'sent': report.sent, 'left': report.left}),
        background: colors.warning,
        duration: const Duration(seconds: 6),
      );
    } else {
      _show(
        icon: Icons.cloud_queue_rounded,
        text: 'sync_notice.not_yet'.trParams({'left': report.left}),
        background: colors.warning,
        duration: const Duration(seconds: 6),
      );
    }
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _show({
    required IconData icon,
    required String text,
    Color? background,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return null;
    // One sync message at a time: "syncing…" is replaced by its result.
    // `remove`, not `hide`: a fast sync finishes before "syncing…" has even
    // started animating in, and `hideCurrentSnackBar` ignores a snackbar in
    // that state — the result would queue behind it for ten seconds.
    messenger.removeCurrentSnackBar();
    return messenger.showSnackBar(SnackBar(
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
