import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_approval_history_view.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_detail_actions.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_detail_header.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_detail_lines_table.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_detail_totals_card.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_offline_draft_banner.dart';

/// The scrolling body of the quotation detail screen, from header to actions.
class QuotationDetailContent extends StatelessWidget {
  const QuotationDetailContent({
    super.key,
    required this.detail,
    required this.history,
    required this.isSubmitting,
    required this.isCancelling,
    required this.onEdit,
    required this.onConvertToSalesOrder,
    this.isOfflineDraft = false,
  });

  final QuotationDetail detail;
  final List<QuotationApprovalHistory> history;
  final bool isSubmitting;
  final bool isCancelling;
  final bool isOfflineDraft;
  final VoidCallback onEdit;
  final VoidCallback onConvertToSalesOrder;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (isOfflineDraft) ...[
          const QuotationOfflineDraftBanner(),
          SizedBox(height: context.rh(12)),
        ],
        QuotationDetailHeader(detail: detail),
        SizedBox(height: context.rh(16)),
        QuotationDetailLinesTable(lines: detail.lines),
        SizedBox(height: context.rh(16)),
        QuotationDetailTotalsCard(totals: detail.totals),
        if (history.isNotEmpty) ...[
          SizedBox(height: context.rh(20)),
          Text(
            'Approval Trail',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(15),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.rh(8)),
          QuotationApprovalHistoryView(history: history),
        ],
        SizedBox(height: context.rh(24)),
        QuotationDetailActions(
          detail: detail,
          isSubmitting: isSubmitting,
          isCancelling: isCancelling,
          onEdit: onEdit,
          onConvertToSalesOrder: onConvertToSalesOrder,
        ),
      ],
    );
  }
}
