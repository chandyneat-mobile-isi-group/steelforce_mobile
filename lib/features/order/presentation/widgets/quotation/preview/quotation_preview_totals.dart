import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/discount_summary_section.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/preview/quotation_preview_decorations.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';

/// Subtotal, discount breakdown, tax and grand total for the preview.
class QuotationPreviewTotals extends StatelessWidget {
  const QuotationPreviewTotals({
    super.key,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.invoiceDiscounts,
    required this.isTaxApplicable,
    required this.currency,
  });

  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final List<InvoiceDiscountItem> invoiceDiscounts;
  final bool isTaxApplicable;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // One pending line makes the whole document pending: a subtotal that
    // silently drops a line is a smaller, wronger number than none at all.
    final pending = items.hasPendingPricing;

    String amount(double value) =>
        PricingText.amount(pending ? null : value, currency: currency);

    final rowLabel = TextStyle(
      fontSize: context.rsp(14),
      fontWeight: FontWeight.w500,
      color: colors.textPrimary,
    );
    final rowAmount = TextStyle(
      fontSize: context.rsp(14),
      fontWeight: FontWeight.w600,
      color: colors.textPrimary,
    );
    final totalStyle = TextStyle(
      fontSize: context.rsp(16),
      fontWeight: FontWeight.w900,
      color: colors.brandNavy,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountRow(
          label: Text('orders.quotation_extra.subtotal'.tr, style: rowLabel),
          amount: Text(amount(subtotal), style: rowAmount),
        ),
        SizedBox(height: context.rh(12)),
        DiscountSummarySection(
          items: items,
          invoiceDiscounts: invoiceDiscounts,
          totalDiscountOverride: pending ? null : discount,
        ),
        SizedBox(height: context.rh(12)),
        _AmountRow(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('orders.quotation_extra.tax'.tr, style: rowLabel),
              SizedBox(width: context.rw(6)),
              if (isTaxApplicable)
                Text(
                  '(10%)',
                  style: TextStyle(
                    fontSize: context.rsp(11),
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                )
              else
                const _TaxExemptBadge(),
            ],
          ),
          amount: Text(
            amount(isTaxApplicable ? tax : 0.0),
            style: rowAmount,
          ),
        ),
        SizedBox(height: context.rh(12)),
        const DashedDivider(),
        SizedBox(height: context.rh(12)),
        _AmountRow(
          label: Text('orders.quotation_extra.total'.tr, style: totalStyle),
          amount: Text(amount(total), style: totalStyle),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

  final Widget label;
  final Widget amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [label, amount],
    );
  }
}

class _TaxExemptBadge extends StatelessWidget {
  const _TaxExemptBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(6),
        vertical: context.rh(2),
      ),
      decoration: BoxDecoration(
        color: colors.brandNavy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.rr(4)),
      ),
      child: Text(
        'Exempt',
        style: TextStyle(
          fontSize: context.rsp(10.5),
          fontWeight: FontWeight.w700,
          color: colors.brandNavy,
        ),
      ),
    );
  }
}
