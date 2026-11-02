import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_status_l10n.dart';

/// The small tinted pill on a Sync Center quotation card showing its sync
/// status (Accepted, Failed, Conflict, …) in the status colour.
class QuotationStatusChip extends StatelessWidget {
  const QuotationStatusChip({
    super.key,
    required this.status,
    required this.color,
  });
  final QuotationSyncStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      // `status.label(context)` — the enum's `label` was a String getter, not a
      // method, so this did not compile at all; the sheet could not build.
      // Now read from `orders.sync_status.*`, which was already translated in
      // both language files and had no caller.
      child: Text(
        status.localizedLabel,
        style: TextStyle(
            color: color,
            fontSize: context.rsp(10.5),
            fontWeight: FontWeight.w800),
      ),
    );
  }
}
