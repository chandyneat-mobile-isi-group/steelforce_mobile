import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Check Out (outlined) and Continue (filled) buttons along the bottom of the
/// "Continue visit" card, in the info colour. No [onCheckOut] — the visit
/// cannot be checked out yet — leaves Continue alone across the row.
class ContinueVisitButtons extends StatelessWidget {
  const ContinueVisitButtons({
    super.key,
    required this.onCheckOut,
    required this.onContinue,
  });
  final VoidCallback? onCheckOut;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.rr(10)),
    );
    final padding = EdgeInsets.symmetric(vertical: context.rh(10));
    final labelStyle = TextStyle(
      fontSize: context.rsp(12.5),
      fontWeight: FontWeight.w700,
    );
    final checkOut = onCheckOut;
    return Row(
      children: [
        if (checkOut != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: checkOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.info,
                side: BorderSide(color: colors.info.withValues(alpha: 0.5)),
                padding: padding,
                shape: shape,
              ),
              child: Text('sync.check_out'.tr, style: labelStyle),
            ),
          ),
          SizedBox(width: context.rw(10)),
        ],
        Expanded(
          child: FilledButton.icon(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: colors.info,
              padding: padding,
              shape: shape,
            ),
            icon: Icon(Icons.play_arrow_rounded, size: context.rsp(18)),
            label: Text('common.continue'.tr, style: labelStyle),
          ),
        ),
      ],
    );
  }
}
