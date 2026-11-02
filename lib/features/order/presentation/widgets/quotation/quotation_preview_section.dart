import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/manual_price_input_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_items_table.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';
import 'package:steelforce/shared/widgets/painters/dashed_rrect.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/discount_summary_section.dart';

class QuotationPreviewSection extends StatelessWidget {
  const QuotationPreviewSection({
    super.key,
    this.shopName,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.items,
    this.invoiceDiscounts = const [],
    this.isTaxApplicable = true,
    this.currency = 'USD',
    this.isEstimate = false,
    this.requiredApprovalLevel = 0,
    this.warnings = const [],
    this.agreements = const [],
    this.onEnlargeTap,
    this.isEditable = true,
    this.onEditPrice,
    this.onEditDiscount,
  });

  final String? shopName;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final List<CartItem> items;
  final List<InvoiceDiscountItem> invoiceDiscounts;
  final bool isTaxApplicable;
  final String currency;
  final bool isEstimate;
  final int requiredApprovalLevel;
  final List<QuotationWarning> warnings;
  final List<DepotAgreement> agreements;
  final VoidCallback? onEnlargeTap;
  final bool isEditable;
  final void Function(CartItem item)? onEditPrice;
  final void Function(CartItem item)? onEditDiscount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // One pending line makes the whole document pending: a subtotal that
    // silently drops a line is a smaller, wronger number than none at all.
    final pending = items.hasPendingPricing;

    return CustomPaint(
      painter: _DottedBorderPainter(
        borderColor: colors.border,
        backgroundColor: colors.card,
        strokeWidth: 1.5,
        radius: context.rr(16),
        dashLength: 4.0,
        gap: 4.0,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(context.rw(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The SteelForce lockup, ink chosen from the theme —
                      // this preview sits on `colors.card`, which follows the
                      // app theme, so dark ink in light mode and light ink in
                      // dark. Replaces the two hand-picked rasters
                      // (`isi_main_screen_logo.png` / `darkmood_logo.jpg`),
                      // which were drawn `BoxFit.cover` into a 120x40 box the
                      // artwork does not fit — that cropped the wordmark.
                      BrandLogo(height: context.rh(40)),
                      SizedBox(height: context.rh(6)),
                      Text(
                        'orders.quotation.builder_title'.tr,
                        style: TextStyle(
                          fontSize: context.rsp(14),
                          fontWeight: FontWeight.w900,
                          color: colors.brandNavy,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: context.rh(2)),
                      Text(
                        '${shopName ?? 'orders.quotation_extra.walk_in'.tr} · ${'orders.quotation_extra.today'.tr}',
                        style: TextStyle(
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: context.rh(8)),
                      // Server status chips: estimate & approval level
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (isEstimate)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rw(8),
                                vertical: context.rh(3),
                              ),
                              decoration: BoxDecoration(
                                color: colors.warning.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(context.rr(6)),
                                border: Border.all(
                                  color: colors.warning.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: context.rw(11),
                                    color: colors.warningAlt,
                                  ),
                                  SizedBox(width: context.rw(4)),
                                  Text(
                                    'orders.quotation_preview.estimate_offline'
                                        .tr,
                                    style: TextStyle(
                                      fontSize: context.rsp(10.5),
                                      fontWeight: FontWeight.w700,
                                      color: colors.warningAlt,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rw(8),
                              vertical: context.rh(3),
                            ),
                            decoration: BoxDecoration(
                              color: (requiredApprovalLevel > 0
                                      ? colors.warning
                                      : colors.success)
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(context.rr(6)),
                              border: Border.all(
                                color: (requiredApprovalLevel > 0
                                        ? colors.warning
                                        : colors.success)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  requiredApprovalLevel > 0
                                      ? Icons.shield_outlined
                                      : Icons.check_circle_outline_rounded,
                                  size: context.rw(11),
                                  color: requiredApprovalLevel > 0
                                      ? colors.warningAlt
                                      : colors.success,
                                ),
                                SizedBox(width: context.rw(4)),
                                Text(
                                  requiredApprovalLevel > 0
                                      ? 'orders.quotation_preview.approval_level'
                                          .trParams({
                                          'level': '$requiredApprovalLevel',
                                        })
                                      : 'orders.quotation_preview.auto_approved'
                                          .tr,
                                  style: TextStyle(
                                    fontSize: context.rsp(10.5),
                                    fontWeight: FontWeight.w700,
                                    color: requiredApprovalLevel > 0
                                        ? colors.warningAlt
                                        : colors.success,
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
                if (onEnlargeTap != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: onEnlargeTap,
                      borderRadius: BorderRadius.circular(context.rr(8)),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.rw(10),
                            vertical: context.rh(5)),
                        decoration: BoxDecoration(
                          color: colors.surfaceSoft,
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(context.rr(8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              size: context.rw(14),
                              color: colors.brandNavy,
                            ),
                            SizedBox(width: context.rw(4)),
                            Text(
                              'orders.quotation_extra.enlarge'.tr,
                              style: TextStyle(
                                fontSize: context.rsp(11),
                                fontWeight: FontWeight.w700,
                                color: colors.brandNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Standing depot agreement chips
            if (agreements.isNotEmpty) ...[
              SizedBox(height: context.rh(12)),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: agreements.map((ag) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rw(8),
                      vertical: context.rh(3),
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(context.rr(6)),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: context.rw(11),
                          color: colors.brandNavy,
                        ),
                        SizedBox(width: context.rw(4)),
                        Text(
                          'orders.quotation_preview.agreement'.trParams({
                            'percent': ag.percent.toStringAsFixed(1),
                            'category': ag.category,
                          }),
                          style: TextStyle(
                            fontSize: context.rsp(10.5),
                            fontWeight: FontWeight.w600,
                            color: colors.brandNavy,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Server warnings alert
            if (warnings.isNotEmpty) ...[
              SizedBox(height: context.rh(12)),
              Container(
                padding: EdgeInsets.all(context.rw(10)),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(context.rr(8)),
                  border: Border.all(
                    color: colors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: warnings.map((w) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: context.rh(2)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: context.rw(14),
                            color: colors.warningAlt,
                          ),
                          SizedBox(width: context.rw(6)),
                          Expanded(
                            child: Text(
                              w.message ?? w.code,
                              style: TextStyle(
                                fontSize: context.rsp(11),
                                color: colors.warningAlt,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            SizedBox(height: context.rh(16)),
            const _DashedDivider(),
            SizedBox(height: context.rh(16)),

            // --- ENTERPRISE QUOTATION ITEMS TABLE ---
            QuotationItemsTable(
              items: items,
              isEditable: isEditable,
              currency: currency,
              onEditPrice:
                  onEditPrice ?? (item) => _handleEditPrice(context, item),
              onEditDiscount: onEditDiscount,
            ),

            SizedBox(height: context.rh(8)),
            const _DashedDivider(),
            SizedBox(height: context.rh(14)),

            // Pricing Rows Section Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'orders.quotation_extra.subtotal'.tr,
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  PricingText.amount(
                    pending ? null : subtotal,
                    decimals: 2,
                    currency: currency,
                  ),
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rh(12)),

            // Structured Discount & Promotion Breakdown
            DiscountSummarySection(
              items: items,
              invoiceDiscounts: invoiceDiscounts,
              totalDiscountOverride: pending ? null : discount,
            ),
            SizedBox(height: context.rh(12)),

            // Tax Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'orders.quotation_extra.tax'.tr,
                      style: TextStyle(
                        fontSize: context.rsp(14),
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (!isTaxApplicable) ...[
                      SizedBox(width: context.rw(6)),
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
                          'orders.quotation_preview.exempt'.tr,
                          style: TextStyle(
                            fontSize: context.rsp(10.5),
                            fontWeight: FontWeight.w700,
                            color: colors.brandNavy,
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(width: context.rw(6)),
                      Text(
                        '(10%)',
                        style: TextStyle(
                          fontSize: context.rsp(11),
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  PricingText.amount(
                    pending ? null : (isTaxApplicable ? tax : 0.0),
                    decimals: 2,
                    currency: currency,
                  ),
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rh(12)),
            const _DashedDivider(),
            SizedBox(height: context.rh(12)),

            // Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'orders.quotation_extra.total'.tr,
                  style: TextStyle(
                    fontSize: context.rsp(16),
                    fontWeight: FontWeight.w900,
                    color: colors.brandNavy,
                  ),
                ),
                Text(
                  PricingText.amount(
                    pending ? null : total,
                    decimals: 2,
                    currency: currency,
                  ),
                  style: TextStyle(
                    fontSize: context.rsp(16),
                    fontWeight: FontWeight.w900,
                    color: colors.brandNavy,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rh(14)),
            const _DashedDivider(),
            SizedBox(height: context.rh(12)),

            // Bottom Disclaimer Footer Layout
            Text(
              'orders.quotation_extra.quote_disclaimer'.tr,
              style: TextStyle(
                fontSize: context.rsp(11),
                fontWeight: FontWeight.w500,
                color: colors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEditPrice(BuildContext context, CartItem item) async {
    // Only allow manual pricing if material cannot get price from backend!
    try {
      final p = context.read<PricingCubit>().state[item.product.materialNumber];
      if (p != null && p.hasAmount) {
        // Backend price succeeded; manual price is disallowed!
        return;
      }
    } catch (_) {}

    if (!item.isManualPrice && !item.isPricePending) {
      // Line is priced by backend or catalog, manual price is disallowed!
      return;
    }

    final price = await showManualPriceInputSheet(
      context: context,
      item: item,
      currentPrice: item.isManualPrice ? item.unitPriceOverride : null,
    );
    if (price != null && context.mounted) {
      try {
        await context.read<CartCubit>().updateUnitPrice(
              item.id,
              price > 0 ? price : null,
              isManualPrice: true,
            );
      } catch (_) {
        // Ignored if CartCubit not available in current scope.
      }
    }
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color borderColor;
  final Color backgroundColor;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gap;

  _DottedBorderPainter({
    required this.borderColor,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      halfWidth,
      halfWidth,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(radius - halfWidth));

    // 1. Paint the solid background first
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // 2. Prepare the border stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // 3. Draw the dotted border cleanly on top of the background edge.
    //    Uses the polyline walker rather than PathMetrics.extractPath, which
    //    overflows the stack on web — see drawDashedRRect's doc comment.
    drawDashedRRect(canvas, rrect, borderPaint, dash: dashLength, gap: gap);
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap;
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.divider),
              ),
            );
          }),
        );
      },
    );
  }
}
