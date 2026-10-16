import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';

/// Gross, discount, tax and net totals for a quotation.
class QuotationDetailTotalsCard extends StatelessWidget {
  const QuotationDetailTotalsCard({super.key, required this.totals});

  final QuotationTotals totals;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(context.rr(14)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          _TotalsRow(
            label: 'Subtotal (Gross)',
            amount: totals.gross,
            currency: totals.currency,
          ),
          if (totals.discountTotal > 0) ...[
            const SizedBox(height: 8),
            _TotalsRow(
              label: 'Discounts Total',
              amount: -totals.discountTotal,
              currency: totals.currency,
              textColor: Colors.green.shade700,
            ),
          ],
          const SizedBox(height: 8),
          _TotalsRow(
            label:
                totals.tax == null || totals.tax! <= 0 ? 'Tax (Exempt)' : 'Tax',
            amount: totals.tax ?? 0.0,
            currency: totals.currency,
          ),
          Divider(color: colors.divider, height: 20),
          _TotalsRow(
            label: 'Total Net',
            amount: totals.net,
            currency: totals.currency,
            isEmphasized: true,
            textColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.amount,
    required this.currency,
    this.textColor,
    this.isEmphasized = false,
  });

  final String label;
  final double amount;
  final String currency;
  final Color? textColor;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isEmphasized ? colors.textPrimary : colors.textSecondary,
            fontSize: context.rsp(isEmphasized ? 15 : 13),
            fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          PricingText.amount(amount, currency: currency),
          style: TextStyle(
            color: textColor ?? colors.textPrimary,
            fontSize: context.rsp(isEmphasized ? 16 : 13),
            fontWeight: isEmphasized ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
