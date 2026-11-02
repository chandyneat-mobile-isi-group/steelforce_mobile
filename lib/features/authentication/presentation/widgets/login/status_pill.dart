import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

enum AuthVibeStatus { idle, verifying, error, success }

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    this.message,
    this.verifyingLabel,
    this.onDark = false,
  });

  final AuthVibeStatus status;
  final String? message;

  /// Replaces the generic "Verifying…" while [status] is verifying.
  final String? verifyingLabel;

  /// Drawn on the sign-in photo's navy rather than a themed surface: the
  /// theme's error red is tuned for white and goes dim there.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (status == AuthVibeStatus.idle) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (Color color, IconData? icon, String text) = switch (status) {
      AuthVibeStatus.verifying => (
          onDark ? AuthInk.accent : scheme.primary,
          null,
          verifyingLabel ?? 'auth.verifying'.tr,
        ),
      AuthVibeStatus.success => (
          colors.success,
          Icons.check_circle,
          'auth.youre_in'.tr
        ),
      AuthVibeStatus.error => (
          onDark ? AuthInk.error : scheme.error,
          Icons.error_outline,
          message ?? 'common.something_went_wrong'.tr
        ),
      AuthVibeStatus.idle => (colors.textSecondary, null, ''),
    };

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: context.rh(14)),
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(14),
        vertical: context.rh(12),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          if (status == AuthVibeStatus.verifying)
            SizedBox(
              width: context.rr(16),
              height: context.rr(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else if (icon != null)
            Icon(icon, size: context.rr(18), color: color),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: context.rsp(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
