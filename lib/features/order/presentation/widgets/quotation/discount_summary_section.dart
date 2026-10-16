import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/demo_cart_promotions.dart';

/// An invoice-level discount applied to the entire quotation/order.
class InvoiceDiscountItem {
  const InvoiceDiscountItem({
    required this.name,
    required this.rule,
    required this.amount,
  });

  /// Name of the discount/promotion, e.g. "Summer Promotion", "COD / Pickup Discount".
  final String name;

  /// The discount rule/method, e.g. "3%", "$1.00", "1%".
  final String rule;

  /// The calculated monetary discount amount in USD, e.g. 3.00.
  final double amount;
}

/// A line-level discount or promotion rule on a specific SKU/product.
class SkuDiscountLine {
  const SkuDiscountLine({
    this.promotionName,
    required this.rule,
    this.calculatedAmount,
    this.freeQuantity = 0,
    this.unit,
  });

  /// The promotion name when available, e.g. "Buy More", "Special Offer", "Roofing Sheet Free Goods".
  final String? promotionName;

  /// The discount rule/offer, e.g. "3%", "$1.00", "Buy 10 Get 2 Free", "Free 20".
  final String rule;

  /// Calculated monetary reduction, or null if this is a free-quantity promotion.
  final double? calculatedAmount;

  /// Free units awarded, or 0 if this is a monetary discount.
  final int freeQuantity;

  /// The unit of measurement, e.g. "units", "Sheets", "KG".
  final String? unit;

  bool get isFreeQuantity => freeQuantity > 0;
}

/// A product/SKU with its associated line discounts and promotions.
class SkuDiscountGroup {
  const SkuDiscountGroup({
    required this.productName,
    required this.sku,
    required this.lines,
  });

  final String productName;
  final String sku;
  final List<SkuDiscountLine> lines;
}

/// Formats and renders the structured Discount & Promotion Breakdown.
///
/// Distinguishes between:
/// 1. Discount rule (e.g. 3%, $1.00, Free 20)
/// 2. Discount source (Invoice vs SKU/Product)
/// 3. Promotion name (when available)
/// 4. Calculated discount amount (monetary reduction)
/// 5. Free quantity (kept strictly separate from monetary reductions)
class DiscountSummarySection extends StatelessWidget {
  const DiscountSummarySection({
    super.key,
    required this.items,
    this.invoiceDiscounts = const [],
    this.totalDiscountOverride,
  });

  final List<CartItem> items;
  final List<InvoiceDiscountItem> invoiceDiscounts;
  final double? totalDiscountOverride;

  /// Extracts SKU discount groups from cart items.
  static List<SkuDiscountGroup> extractSkuDiscounts(List<CartItem> items) {
    final groups = <SkuDiscountGroup>[];

    for (final item in items) {
      final lines = <SkuDiscountLine>[];

      // 1. Monetary percentage discount on this line
      if (item.discountPercent > 0) {
        final percentFormatted =
            item.discountPercent.truncateToDouble() == item.discountPercent
                ? '${item.discountPercent.toStringAsFixed(0)}%'
                : '${item.discountPercent.toStringAsFixed(1)}%';

        lines.add(
          SkuDiscountLine(
            promotionName:
                DemoCartPromotions.promotionNameFor(item) ?? 'Rep Discount',
            rule: percentFormatted,
            calculatedAmount: item.lineDiscount,
          ),
        );
      }

      // 2. Free quantity promotion on this line (if any)
      final freeUnits = DemoCartPromotions.freeQuantityFor(item);
      if (freeUnits > 0) {
        final freeRule =
            DemoCartPromotions.freeRuleFor(item) ?? 'Free $freeUnits';
        final promoName =
            DemoCartPromotions.promotionNameFor(item) ?? 'Free Goods Promotion';
        final unitLabel = item.unit.isNotEmpty ? item.unit : 'unit';

        lines.add(
          SkuDiscountLine(
            promotionName: promoName,
            rule: freeRule,
            freeQuantity: freeUnits,
            unit: unitLabel,
          ),
        );
      }

      if (lines.isNotEmpty) {
        final pName = item.product.name.isNotEmpty
            ? item.product.name
            : (item.product.code.isNotEmpty ? item.product.code : 'Product');
        final skuCode = item.product.sku.isNotEmpty
            ? item.product.sku
            : (item.product.materialCode.isNotEmpty
                ? item.product.materialCode
                : item.product.id);

        groups.add(
          SkuDiscountGroup(
            productName: pName,
            sku: skuCode,
            lines: lines,
          ),
        );
      }
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final skuGroups = extractSkuDiscounts(items);

    // Sum all monetary discounts from invoice discounts + SKU line discounts
    final double invoiceTotal = invoiceDiscounts.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );

    final double skuMonetaryTotal = skuGroups.fold(
      0.0,
      (sum, group) =>
          sum +
          group.lines.fold(
            0.0,
            (lSum, line) => lSum + (line.calculatedAmount ?? 0.0),
          ),
    );

    final double calculatedTotal = invoiceTotal + skuMonetaryTotal;
    final double totalDiscount = totalDiscountOverride ?? calculatedTotal;

    // Total free units across all items
    final int totalFreeUnits = skuGroups.fold(
      0,
      (sum, group) =>
          sum +
          group.lines.fold(
            0,
            (lSum, line) => lSum + line.freeQuantity,
          ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      padding: EdgeInsets.all(context.rw(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Discount Summary ──
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: context.rw(15),
                color: colors.brandNavy,
              ),
              SizedBox(width: context.rw(6)),
              Expanded(
                child: Text(
                  'Discount Summary',
                  style: TextStyle(
                    fontSize: context.rsp(13),
                    fontWeight: FontWeight.w800,
                    color: colors.brandNavy,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (totalDiscount > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(8),
                    vertical: context.rh(2),
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.rr(6)),
                  ),
                  child: Text(
                    '-\$${totalDiscount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: context.rsp(11.5),
                      fontWeight: FontWeight.w700,
                      color: colors.success,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: context.rh(10)),
          Divider(color: colors.divider, height: 1),
          SizedBox(height: context.rh(10)),

          // ── A. Invoice Discounts ──
          Text(
            'Invoice Discounts',
            style: TextStyle(
              fontSize: context.rsp(11.5),
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: context.rh(4)),
          if (invoiceDiscounts.isEmpty)
            Padding(
              padding: EdgeInsets.only(left: context.rw(8), top: context.rh(2)),
              child: Text(
                'None',
                style: TextStyle(
                  fontSize: context.rsp(11.5),
                  color: colors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...invoiceDiscounts.map((inv) {
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(4),
                  vertical: context.rh(2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontSize: context.rsp(12),
                        fontWeight: FontWeight.bold,
                        color: colors.brandNavy,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: context.rsp(12),
                            color: colors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: inv.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: ' — ${inv.rule} → ',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                            TextSpan(
                              text: '-\$${inv.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          SizedBox(height: context.rh(10)),

          // ── B. SKU Discounts ──
          Text(
            'SKU Discounts',
            style: TextStyle(
              fontSize: context.rsp(11.5),
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: context.rh(4)),
          if (skuGroups.isEmpty)
            Padding(
              padding: EdgeInsets.only(left: context.rw(8), top: context.rh(2)),
              child: Text(
                'None',
                style: TextStyle(
                  fontSize: context.rsp(11.5),
                  color: colors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...skuGroups.map((group) {
              return Padding(
                padding: EdgeInsets.only(bottom: context.rh(6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product / SKU Header
                    Padding(
                      padding: EdgeInsets.only(left: context.rw(4)),
                      child: Row(
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              fontSize: context.rsp(12),
                              fontWeight: FontWeight.bold,
                              color: colors.brandNavy,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${group.productName} / ${group.sku}',
                              style: TextStyle(
                                fontSize: context.rsp(12),
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    // Sub-bullet promotion / discount lines
                    ...group.lines.map((line) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: context.rw(20),
                          top: context.rh(2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontSize: context.rsp(11),
                                color: colors.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: line.isFreeQuantity
                                  ? _buildFreeQuantityText(
                                      context, colors, line)
                                  : _buildMonetaryDiscountText(
                                      context, colors, line),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

          SizedBox(height: context.rh(8)),
          Divider(color: colors.divider, height: 1),
          SizedBox(height: context.rh(8)),

          // ── Total Discount Row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Discount',
                style: TextStyle(
                  fontSize: context.rsp(12.5),
                  fontWeight: FontWeight.w800,
                  color: colors.brandNavy,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: context.rw(6),
                  runSpacing: context.rh(4),
                  children: [
                    Text(
                      totalDiscount > 0
                          ? '-\$${totalDiscount.toStringAsFixed(2)}'
                          : '\$0.00',
                      style: TextStyle(
                        fontSize: context.rsp(13),
                        fontWeight: FontWeight.w800,
                        color: totalDiscount > 0
                            ? colors.success
                            : colors.textPrimary,
                      ),
                    ),
                    if (totalFreeUnits > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rw(6),
                          vertical: context.rh(2),
                        ),
                        decoration: BoxDecoration(
                          color: colors.brandNavy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(context.rr(4)),
                        ),
                        child: Text(
                          '+$totalFreeUnits free ${totalFreeUnits == 1 ? 'unit' : 'units'}',
                          style: TextStyle(
                            fontSize: context.rsp(10.5),
                            fontWeight: FontWeight.w700,
                            color: colors.brandNavy,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonetaryDiscountText(
    BuildContext context,
    AppThemeColors colors,
    SkuDiscountLine line,
  ) {
    final prefix = line.promotionName != null && line.promotionName!.isNotEmpty
        ? 'Promotion: ${line.promotionName} — '
        : '';
    final amountFormatted = line.calculatedAmount != null
        ? '-\$${line.calculatedAmount!.toStringAsFixed(2)}'
        : '';

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: context.rsp(11.5),
          color: colors.textPrimary,
        ),
        children: [
          TextSpan(
            text: prefix,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          TextSpan(
            text: '${line.rule} → ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          TextSpan(
            text: amountFormatted,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeQuantityText(
    BuildContext context,
    AppThemeColors colors,
    SkuDiscountLine line,
  ) {
    final prefix = line.promotionName != null && line.promotionName!.isNotEmpty
        ? 'Promotion: ${line.promotionName} — '
        : '';
    final unit =
        line.unit != null && line.unit!.isNotEmpty ? line.unit! : 'unit';
    final unitsLabel = line.freeQuantity == 1
        ? '1 free $unit'
        : '${line.freeQuantity} free ${unit}s';

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: context.rsp(11.5),
          color: colors.textPrimary,
        ),
        children: [
          TextSpan(
            text: prefix,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          TextSpan(
            text: '${line.rule} → ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          TextSpan(
            text: unitsLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colors.brandNavy,
            ),
          ),
        ],
      ),
    );
  }
}
