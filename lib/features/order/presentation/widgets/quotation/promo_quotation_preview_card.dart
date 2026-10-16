import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotions_mock_data.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// Shows how a promotion applies inside a quotation with standard enterprise
/// columns: NO., Material, Quantity, Unit Price (USD), Discount, Subtotal, Total (USD).
class PromoQuotationPreviewCard extends StatelessWidget {
  const PromoQuotationPreviewCard({
    super.key,
    required this.promo,
  });

  final PromoView promo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final lines = getQuotationSampleLinesForPromo(promo);

    return Container(
      margin: EdgeInsets.only(top: context.rh(8)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(10)),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(10),
              vertical: context.rh(6),
            ),
            color: colors.brandNavy.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: context.rw(14),
                  color: colors.brandNavy,
                ),
                SizedBox(width: context.rw(6)),
                Text(
                  'QUOTATION FORMATTED PREVIEW',
                  style: TextStyle(
                    fontSize: context.rsp(10.5),
                    fontWeight: FontWeight.w800,
                    color: colors.brandNavy,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'Currency: USD',
                  style: TextStyle(
                    fontSize: context.rsp(10),
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (final line in lines)
            Padding(
              padding: EdgeInsets.all(context.rw(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: NO. and Material
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rw(6),
                          vertical: context.rh(2),
                        ),
                        decoration: BoxDecoration(
                          color: colors.brandNavy,
                          borderRadius: BorderRadius.circular(context.rr(4)),
                        ),
                        child: Text(
                          'NO. ${line.lineNo}',
                          style: TextStyle(
                            fontSize: context.rsp(10),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: context.rw(6)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Material: ${line.materialCode}',
                              style: TextStyle(
                                fontSize: context.rsp(11),
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              line.materialName,
                              style: TextStyle(
                                fontSize: context.rsp(12),
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rh(8)),
                  Divider(color: colors.divider, height: 1),
                  SizedBox(height: context.rh(6)),
                  // Metrics Grid: Quantity, Unit Price, Subtotal, Discount, Total
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quantity',
                                style: TextStyle(
                                    fontSize: context.rsp(9.5),
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary)),
                            Text('${line.quantity.toInt()} ${line.unit}',
                                style: TextStyle(
                                    fontSize: context.rsp(11.5),
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unit Price (USD)',
                                style: TextStyle(
                                    fontSize: context.rsp(9.5),
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary)),
                            Text('\$${line.unitPriceUsd.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: context.rsp(11.5),
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subtotal',
                                style: TextStyle(
                                    fontSize: context.rsp(9.5),
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary)),
                            Text('\$${line.subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: context.rsp(11.5),
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rh(6)),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Discount',
                                style: TextStyle(
                                    fontSize: context.rsp(9.5),
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary)),
                            Text(
                              line.bonusNote ??
                                  (line.discountPercent > 0
                                      ? '-${line.discountPercent.toStringAsFixed(1)}% (-\$${line.discountAmount.toStringAsFixed(2)})'
                                      : '-'),
                              style: TextStyle(
                                  fontSize: context.rsp(11),
                                  fontWeight: FontWeight.w700,
                                  color: colors.success),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total (USD)',
                                style: TextStyle(
                                    fontSize: context.rsp(9.5),
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary)),
                            Text(
                              '\$${line.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: context.rsp(12.5),
                                fontWeight: FontWeight.w800,
                                color: colors.brandNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
