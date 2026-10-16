import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';

/// The status badge shown on an order row and on its detail header.
///
/// Carries an **icon as well as a colour** (FS-A11Y-3): pending and confirmed
/// are amber and green, which is precisely the pair a red-green colour-blind
/// rep cannot separate, and this badge is the only thing on the row that says
/// whether the order is committed.
class SalesOrderStatusChip extends StatelessWidget {
  const SalesOrderStatusChip(
      {super.key, required this.status, this.compact = false});

  final SalesOrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final (color, icon, labelKey) = switch (status) {
      SalesOrderStatus.pending => (
          colors.warning,
          Icons.schedule_rounded,
          'orders.sales_order.status_pending',
        ),
      SalesOrderStatus.confirmed => (
          colors.success,
          Icons.check_circle_rounded,
          'orders.sales_order.status_confirmed',
        ),
    };

    final label = labelKey.tr;

    return Semantics(
      label: '${'orders.sales_order.status_label'.tr}: $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(compact ? 8 : 10),
          vertical: context.rh(compact ? 3 : 5),
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(context.rr(999)),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.rr(compact ? 12 : 14), color: color),
            SizedBox(width: context.rw(5)),
            // Never height-constrained: Khmer renders taller than Latin
            // (FS-LOC-4) and a fixed box clips it.
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: context.rsp(compact ? 10.5 : 11.5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
