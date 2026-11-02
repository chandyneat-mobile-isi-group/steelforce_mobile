import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_error_l10n.dart';
import 'package:steelforce/features/order/presentation/widgets/sync/pending_quotation_details_sheet.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/pending_sync_info_line.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/quotation_queue_actions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/quotation_status_chip.dart';

/// One quotation card in the Sync Center: shop name + status chip, the
/// items / total / attempt line, what the backend or an admin said, and —
/// when the rep must act — the Discard / Retry / Review prices row.
class QuotationQueueTile extends StatelessWidget {
  const QuotationQueueTile({super.key, required this.item});
  final SyncQueueItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final color = _statusColor(context, item.status);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showPendingQuotationDetails(context, item),
        child: Container(
          padding: EdgeInsets.all(context.rr(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.shopName?.isNotEmpty == true
                          ? item.shopName!
                          : 'sync.quotation_ref'
                              .trParams({'id': item.quotationId}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: context.rsp(13.5),
                          color: scheme.onSurface),
                    ),
                  ),
                  QuotationStatusChip(status: item.status, color: color),
                  SizedBox(width: context.rw(4)),
                  Icon(Icons.chevron_right_rounded,
                      size: context.rr(18), color: colors.textSecondary),
                ],
              ),
              SizedBox(height: context.rh(4)),
              Text(
                [
                  if (item.itemCount != null)
                    'sync.items'.trParams({'count': item.itemCount}),
                  if (item.total != null)
                    NumberFormat.currency(
                            locale: context.languageCode, symbol: r'$')
                        .format(item.total),
                  if (item.attemptCount > 0)
                    'sync.attempt'.trParams({'count': item.attemptCount}),
                ].join(' · '),
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(11.5)),
              ),
              if (item.remoteNumber != null) ...[
                SizedBox(height: context.rh(6)),
                PendingSyncInfoLine(
                  icon: Icons.check_circle_rounded,
                  color: colors.success,
                  text: 'sync.admin_document'.trParams({
                    'id': item.remoteNumber,
                    'status': item.remoteStatus == null
                        ? ''
                        : localizedRemoteStatus(item.remoteStatus!),
                  }),
                ),
              ],
              if (item.decisionReason?.isNotEmpty == true) ...[
                SizedBox(height: context.rh(6)),
                PendingSyncInfoLine(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: colors.warning,
                  text: 'sync.admin_reason'
                      .trParams({'reason': item.decisionReason}),
                ),
              ],
              if (item.status.needsUserAction &&
                  item.status != QuotationSyncStatus.returned) ...[
                SizedBox(height: context.rh(6)),
                PendingSyncInfoLine(
                  icon: Icons.error_outline_rounded,
                  color: scheme.error,
                  text: localizedSyncError(item.errorCode),
                ),
              ],
              if (item.status.needsUserAction) ...[
                SizedBox(height: context.rh(8)),
                QuotationQueueActions(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(BuildContext context, QuotationSyncStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return switch (status) {
      QuotationSyncStatus.accepted => colors.success,
      QuotationSyncStatus.failed ||
      QuotationSyncStatus.rejected =>
        scheme.error,
      QuotationSyncStatus.conflict ||
      QuotationSyncStatus.returned =>
        colors.warning,
      QuotationSyncStatus.syncing ||
      QuotationSyncStatus.submitted =>
        scheme.primary,
      _ => colors.textSecondary,
    };
  }
}
