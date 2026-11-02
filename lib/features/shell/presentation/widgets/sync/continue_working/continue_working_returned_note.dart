import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// "Returned by Admin", with the administrator's reason when they gave one —
/// the reason is the whole point of a return (docs/feature/order/quotation/api/mobile.md).
class ContinueWorkingReturnedNote extends StatelessWidget {
  const ContinueWorkingReturnedNote({super.key, this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = reason?.isNotEmpty == true
        ? 'sync.admin_reason'.trParams({'reason': reason})
        : 'sync.returned_by_admin'.tr;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.reply_rounded, size: context.rsp(14), color: colors.warning),
        SizedBox(width: context.rw(6)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: context.rsp(11.5),
              fontWeight: FontWeight.w600,
              color: colors.warning,
            ),
          ),
        ),
      ],
    );
  }
}
