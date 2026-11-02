import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The Work Mode confirm dialog's full-width actions: the filled
/// "Go Offline / Go Online" confirm (pops `true`) and Cancel (pops `false`).
class WorkModeDialogActions extends StatelessWidget {
  const WorkModeDialogActions({
    super.key,
    required this.toOffline,
    required this.boxScale,
    required this.typeScale,
  });

  /// The mode being switched to; picks the confirm label.
  final bool toOffline;

  /// The dialog's width-class box and type scales (1.0 on phones).
  final double boxScale;
  final double typeScale;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(50 * boxScale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16 * boxScale),
            ),
            textStyle: TextStyle(
              fontSize: 15.5 * typeScale,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(
            toOffline
                ? 'work_mode.switch_offline'.tr
                : 'work_mode.switch_online'.tr,
          ),
        ),
        SizedBox(height: 10 * boxScale),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            minimumSize: Size.fromHeight(46 * boxScale),
            foregroundColor: c.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14 * boxScale),
            ),
            textStyle: TextStyle(
              fontSize: 14.5 * typeScale,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text('common.cancel'.tr),
        ),
      ],
    );
  }
}
