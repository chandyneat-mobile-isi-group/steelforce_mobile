import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The tinted "N item(s) saved on this device are safe" note in the Work
/// Mode confirm dialog, shown when unsent work exists.
class WorkModeUnsentNote extends StatelessWidget {
  const WorkModeUnsentNote({
    super.key,
    required this.unsent,
    required this.boxScale,
    required this.typeScale,
  });

  /// Work saved on this device and not yet sent.
  final int unsent;

  /// The dialog's width-class box and type scales (1.0 on phones).
  final double boxScale;
  final double typeScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * boxScale,
        vertical: 10 * boxScale,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(12 * boxScale),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 18 * boxScale,
            color: scheme.primary,
          ),
          SizedBox(width: 10 * boxScale),
          Expanded(
            child: Text(
              'work_mode.unsent_safe'.trParams({'count': unsent}),
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5 * typeScale,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
