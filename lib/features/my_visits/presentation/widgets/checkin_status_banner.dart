import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Surfaces exactly why check-in is (or isn't) allowed right now — blocked
/// reasons in red, non-blocking fraud/VPN warnings in amber. Covers both
/// "fraud" and "VPN" banners from one widget since they share the same
/// `CheckInValidation` source and layout.
class CheckinStatusBanner extends StatelessWidget {
  const CheckinStatusBanner({
    super.key,
    required this.insideGeofence,
    required this.distanceMeters,
    required this.blockedReason,
    required this.warnings,
  });

  final bool insideGeofence;
  final double distanceMeters;
  final String? blockedReason;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pill(
          color: insideGeofence ? colors.success : colors.warning,
          icon: insideGeofence
              ? Icons.check_circle_rounded
              : Icons.location_searching_rounded,
          text: insideGeofence
              ? 'my_visits.geofence.inside'.tr
              : 'my_visits.geofence.move_closer'
                  .trParams({'distance': distanceMeters.toStringAsFixed(0)}),
        ),
        if (blockedReason != null) ...[
          SizedBox(height: context.rh(8)),
          _Pill(
              color: Theme.of(context).colorScheme.error,
              icon: Icons.block_rounded,
              text: blockedReason!),
        ],
        for (final warning in warnings) ...[
          SizedBox(height: context.rh(8)),
          _Pill(
              color: colors.warning,
              icon: Icons.warning_amber_rounded,
              text: warning),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: context.rr(16), color: color),
          SizedBox(width: context.rw(8)),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
