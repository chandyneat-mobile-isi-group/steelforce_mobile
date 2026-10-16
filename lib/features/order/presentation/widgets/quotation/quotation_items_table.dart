import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/platform/storage/local_files.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/line_discount_chips.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';

/// An enterprise-formatted quotation items table presenting lines with standard
/// commercial columns:
///  * **NO.** (Line sequence number)
///  * **Material** (SAP material code + item description + dimensions/finish)
///  * **Quantity** (Amount + commercial unit)
///  * **Unit Price** (In USD, with manual price input affordance)
///  * **Discount** (Percentage and monetary discount)
///  * **Subtotal** (Gross line value)
///  * **Total** (Net line total after discount)
class QuotationItemsTable extends StatelessWidget {
  const QuotationItemsTable({
    super.key,
    required this.items,
    this.isEditable = false,
    this.onEditPrice,
    this.onEditDiscount,
    this.currency = 'USD',
  });

  final List<CartItem> items;
  final bool isEditable;
  final void Function(CartItem item)? onEditPrice;
  final void Function(CartItem item)? onEditDiscount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.rh(16)),
          child: Text(
            'No items in quotation',
            style: TextStyle(
              fontSize: context.rsp(13),
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Title Header Bar
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rw(12),
            vertical: context.rh(8),
          ),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(context.rr(8)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.format_list_numbered_rounded,
                size: context.rw(16),
                color: colors.brandNavy,
              ),
              Expanded(
                child: Text(
                  'QUOTATION ITEMS (${items.length})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w800,
                    color: colors.brandNavy,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(width: context.rw(8)),
              Text(
                'Currency: $currency',
                style: TextStyle(
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(10)),

        // Item Cards / Rows
        for (var i = 0; i < items.length; i++) ...[
          _QuotationItemCard(
            index: i + 1,
            item: items[i],
            isEditable: isEditable,
            onEditPrice: onEditPrice,
            onEditDiscount: onEditDiscount,
            currency: currency,
          ),
          if (i < items.length - 1) SizedBox(height: context.rh(10)),
        ],
      ],
    );
  }
}

class _QuotationItemCard extends StatelessWidget {
  const _QuotationItemCard({
    required this.index,
    required this.item,
    required this.isEditable,
    this.onEditPrice,
    this.onEditDiscount,
    this.currency = 'USD',
  });

  final int index;
  final CartItem item;
  final bool isEditable;
  final void Function(CartItem item)? onEditPrice;
  final void Function(CartItem item)? onEditDiscount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final scheme = Theme.of(context).colorScheme;

    final product = item.product;
    final int qty = item.quantity.toInt();
    final hasDrawing = item.drawingImagePath != null &&
        localFileExists(item.drawingImagePath!);

    final specParts = <String>[];
    if (item.isCustomized) {
      final m = item.measurements;
      if (m != null && !m.isEmpty) {
        specParts.add(m.toSummaryString());
      }
      if (item.appearance != null && item.appearance!.trim().isNotEmpty) {
        specParts.add(item.appearance!.trim());
      }
    } else if (product.size.isNotEmpty || product.grade.isNotEmpty) {
      specParts.add('${product.size} ${product.grade}'.trim());
    }

    final isManualOverride = item.isManualPrice;
    final unitPriceFormatted =
        item.isPricePending ? null : '\$${item.unitPrice.toStringAsFixed(2)}';
    final subtotalFormatted = item.isPricePending
        ? null
        : '\$${item.lineSubtotal.toStringAsFixed(2)}';
    final discountFormatted = item.isPricePending
        ? null
        : (item.discountPercent > 0
            ? '-${item.discountPercent.toStringAsFixed(0)}% (-\$${item.lineDiscount.toStringAsFixed(2)})'
            : '-');
    final totalFormatted = PricingText.amountOrNull(item.lineTotalOrNull);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(10)),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: NO. + Material Code + Drawing badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(12),
              vertical: context.rh(6),
            ),
            color: colors.surfaceSoft,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(8),
                    vertical: context.rh(2),
                  ),
                  decoration: BoxDecoration(
                    color: colors.brandNavy,
                    borderRadius: BorderRadius.circular(context.rr(4)),
                  ),
                  child: Text(
                    'NO. $index',
                    style: TextStyle(
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: context.rw(8)),
                Expanded(
                  child: Text(
                    product.materialCode.isNotEmpty
                        ? 'Material: ${product.materialCode}'
                        : 'SKU: ${product.sku}',
                    style: TextStyle(
                      fontSize: context.rsp(11.5),
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isManualOverride)
                  Container(
                    margin: EdgeInsets.only(left: context.rw(6)),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rw(6),
                      vertical: context.rh(2),
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(context.rr(4)),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Manual Price (USD)',
                      style: TextStyle(
                        fontSize: context.rsp(10),
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  )
                else if (item.isPricePending)
                  Container(
                    margin: EdgeInsets.only(left: context.rw(6)),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rw(6),
                      vertical: context.rh(2),
                    ),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(context.rr(4)),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: context.rr(10.5),
                          color: colors.warningAlt,
                        ),
                        SizedBox(width: context.rw(3)),
                        Text(
                          "Material doesn't have price",
                          style: TextStyle(
                            fontSize: context.rsp(9.5),
                            fontWeight: FontWeight.w700,
                            color: colors.warningAlt,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Content Body
          Padding(
            padding: EdgeInsets.all(context.rw(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Material Name & Drawing
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isCustomized) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(context.rr(6)),
                        child: Container(
                          width: context.rw(36),
                          height: context.rw(36),
                          color: colors.surfaceSoft,
                          child: hasDrawing
                              ? localFileImage((item.drawingImagePath!),
                                  fit: BoxFit.cover)
                              : Icon(
                                  Icons.tune_rounded,
                                  size: context.rw(18),
                                  color: colors.brandNavy,
                                ),
                        ),
                      ),
                      SizedBox(width: context.rw(8)),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.displayName.isEmpty
                                ? 'orders.quotation_extra.structural_item'.tr
                                : context.localized(product.displayName),
                            style: TextStyle(
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (specParts.isNotEmpty) ...[
                            SizedBox(height: context.rh(2)),
                            Text(
                              specParts.join(' · '),
                              style: TextStyle(
                                fontSize: context.rsp(11),
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          LineDiscountChips(item: item, compact: true),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(10)),
                Divider(color: colors.divider, height: 1),
                SizedBox(height: context.rh(8)),

                // Metrics Grid: Quantity | Unit Price | Subtotal | Discount | Total
                Row(
                  children: [
                    // Quantity
                    Expanded(
                      flex: 2,
                      child: _MetricColumn(
                        label: 'Quantity',
                        value: '$qty ${item.unit}',
                        valueColor: colors.textPrimary,
                      ),
                    ),
                    // Unit Price (USD)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit Price (USD)',
                            style: TextStyle(
                              fontSize: context.rsp(10),
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          SizedBox(height: context.rh(2)),
                          if (unitPriceFormatted != null)
                            (isEditable &&
                                    onEditPrice != null &&
                                    isManualOverride)
                                ? InkWell(
                                    onTap: () => onEditPrice!(item),
                                    borderRadius:
                                        BorderRadius.circular(context.rr(4)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          unitPriceFormatted,
                                          style: TextStyle(
                                            fontSize: context.rsp(13),
                                            fontWeight: FontWeight.w800,
                                            color: scheme.primary,
                                          ),
                                        ),
                                        SizedBox(width: context.rw(3)),
                                        Icon(
                                          Icons.edit_outlined,
                                          size: context.rw(12),
                                          color: scheme.primary,
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                    unitPriceFormatted,
                                    style: TextStyle(
                                      fontSize: context.rsp(13),
                                      fontWeight: FontWeight.w800,
                                      color: isManualOverride
                                          ? scheme.primary
                                          : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF60A5FA)
                                              : colors.brandNavy),
                                    ),
                                  )
                          else if (isEditable && onEditPrice != null)
                            InkWell(
                              onTap: () => onEditPrice!(item),
                              borderRadius:
                                  BorderRadius.circular(context.rr(4)),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rw(6),
                                  vertical: context.rh(2),
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(context.rr(4)),
                                  border: Border.all(
                                    color:
                                        scheme.primary.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: context.rw(13),
                                      color: scheme.primary,
                                    ),
                                    SizedBox(width: context.rw(2)),
                                    Text(
                                      'Input Price (USD)',
                                      style: TextStyle(
                                        fontSize: context.rsp(10.5),
                                        fontWeight: FontWeight.w800,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Text(
                              'Waiting HQ',
                              style: TextStyle(
                                fontSize: context.rsp(11),
                                fontStyle: FontStyle.italic,
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Subtotal
                    Expanded(
                      flex: 2,
                      child: _MetricColumn(
                        label: 'Subtotal',
                        value: subtotalFormatted ?? '—',
                        valueColor: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(8)),
                Row(
                  children: [
                    // Discount
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: (isEditable && onEditDiscount != null)
                            ? () => onEditDiscount!(item)
                            : null,
                        borderRadius: BorderRadius.circular(context.rr(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Discount',
                                  style: TextStyle(
                                    fontSize: context.rsp(10),
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                if (isEditable && onEditDiscount != null) ...[
                                  SizedBox(width: context.rw(3)),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: context.rw(11),
                                    color: scheme.primary,
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: context.rh(2)),
                            Text(
                              discountFormatted ?? '—',
                              style: TextStyle(
                                fontSize: context.rsp(12),
                                fontWeight: FontWeight.w600,
                                color: item.discountPercent > 0
                                    ? colors.success
                                    : (isEditable && onEditDiscount != null
                                        ? scheme.primary
                                        : colors.textSecondary),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Total
                    Expanded(
                      flex: 3,
                      child: _MetricColumn(
                        label: 'Total ($currency)',
                        value: totalFormatted ?? 'Pending',
                        valueColor: colors.brandNavy,
                        isBold: true,
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

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.rsp(10),
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        SizedBox(height: context.rh(2)),
        Text(
          value,
          style: TextStyle(
            fontSize: context.rsp(isBold ? 13 : 12),
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
