import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// A thin warning-tinted strip that appears **only while the device has no
/// network connection**, reassuring the field agent that GPS logs, photos, and
/// captured data are queued on the device and will sync once a connection
/// returns. Collapses to nothing whenever the device is connected.
///
/// Visibility deliberately tracks the OS network interface (Wi-Fi / mobile
/// present) rather than [ConnectivityService]'s API-reachability probe: this
/// strip is a "your network is off" reassurance for the rep, so it must hide the
/// moment the phone has working connectivity — even if the app's gateway happens
/// to be unreachable (e.g. a mock/staging backend). The sync engine and the
/// global status pill still use [ConnectivityService] for real reachability
/// (ADR-005); only this reassurance banner uses device connectivity.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    // Seed with the current state, then react to every interface change.
    _connectivity.checkConnectivity().then(_apply);
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  /// Offline only when the OS reports no active interface at all.
  void _apply(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'my_visits.flow.offline_saved'.tr,
              style: TextStyle(
                color: colors.warning,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
