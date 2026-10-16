import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';

/// The quotation's line items: material, quantity and priced amounts.
class QuotationDetailLinesTable extends StatelessWidget {
  const QuotationDetailLinesTable({super.key, required this.lines});

  final List<QuotationLineItem> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Material',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Qty & Price',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Net',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            separatorBuilder: (_, __) =>
                Divider(color: colors.divider, height: 1),
            itemBuilder: (context, index) {
              final line = lines[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.materialDescription.isNotEmpty
                                ? line.materialDescription
                                : line.materialNumber,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            line.materialNumber,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11),
                            ),
                          ),
                          // Discounts badges
                          if (line.discounts.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: line.discounts.map((d) {
                                final isAg =
                                    d.kind == QuotationDiscountKind.agreement;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAg
                                        ? Colors.blue.withValues(alpha: 0.12)
                                        : Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${isAg ? "Agreement" : "Rep"}: -${d.percent.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: context.rsp(10),
                                      fontWeight: FontWeight.w700,
                                      color: isAg
                                          ? Colors.blue.shade800
                                          : Colors.orange.shade900,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${line.quantity.toStringAsFixed(0)} ${line.unit}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(12.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            line.formattedPrice,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        PricingText.amount(
                          line.net,
                          currency: line.priceCurrency,
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(13.5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
