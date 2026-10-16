import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

/// Document number, revision, status chip, depot, validity and — when an
/// approver returned or rejected it — the decision reason.
class QuotationDetailHeader extends StatelessWidget {
  const QuotationDetailHeader({super.key, required this.detail});

  final QuotationDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusStyle =
        _resolveStatusStyle(detail.status, Theme.of(context), colors);

    // Stretch matches the ListView these rows used to sit in directly.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.number.isNotEmpty ? detail.number : detail.id,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(19),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (detail.revision > 1)
                    Text(
                      'Revision ${detail.revision}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusStyle.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                detail.status,
                style: TextStyle(
                  color: statusStyle.textColor,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(6)),
        Text(
          detail.depotName ?? 'Depot #${detail.depotId}',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(14),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (detail.validTo != null) ...[
          SizedBox(height: context.rh(4)),
          Text(
            '${'orders.quotation.valid_until'.tr}: ${_formatDate(detail.validTo!)}',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12),
            ),
          ),
        ],
        if (detail.decisionReason != null &&
            detail.decisionReason!.isNotEmpty) ...[
          SizedBox(height: context.rh(12)),
          _DecisionReasonBanner(reason: detail.decisionReason!),
        ],
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static ({Color backgroundColor, Color textColor}) _resolveStatusStyle(
      String status, ThemeData theme, AppThemeColors colors) {
    final s = status.toLowerCase();
    if (s.contains('draft')) {
      return (
        backgroundColor: colors.surfaceSoft,
        textColor: colors.textSecondary,
      );
    }
    if (s.contains('returned') ||
        s.contains('waiting') ||
        s.contains('pending')) {
      return (
        backgroundColor: Colors.amber.withValues(alpha: 0.15),
        textColor: Colors.amber.shade900,
      );
    }
    if (s.contains('approved') ||
        s.contains('won') ||
        s.contains('accepted') ||
        s.contains('ordered')) {
      return (
        backgroundColor: Colors.green.withValues(alpha: 0.15),
        textColor: Colors.green.shade800,
      );
    }
    if (s.contains('rejected') ||
        s.contains('cancelled') ||
        s.contains('failed') ||
        s.contains('lost') ||
        s.contains('expired')) {
      return (
        backgroundColor: Colors.red.withValues(alpha: 0.15),
        textColor: Colors.red.shade800,
      );
    }
    if (s.contains('quoted')) {
      return (
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        textColor: theme.colorScheme.primary,
      );
    }
    return (
      backgroundColor: colors.surfaceSoft,
      textColor: colors.textPrimary,
    );
  }
}

class _DecisionReasonBanner extends StatelessWidget {
  const _DecisionReasonBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approver Decision Reason:',
                  style: TextStyle(
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w800,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: context.rsp(13),
                    color: context.appColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
