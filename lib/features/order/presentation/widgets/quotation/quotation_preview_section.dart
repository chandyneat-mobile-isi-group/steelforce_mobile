import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/discount_summary_section.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/manual_price_input_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/preview/quotation_preview_decorations.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/preview/quotation_preview_header.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/preview/quotation_preview_notices.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/preview/quotation_preview_totals.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_items_table.dart';

/// The quotation as the depot will see it: letterhead, notices, line items,
/// totals and disclaimer, on a dashed tear-off card.
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

    return CustomPaint(
      painter: DottedCardBorderPainter(
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
            QuotationPreviewHeader(
              shopName: shopName,
              isEstimate: isEstimate,
              requiredApprovalLevel: requiredApprovalLevel,
              onEnlargeTap: onEnlargeTap,
            ),
            if (agreements.isNotEmpty) ...[
              SizedBox(height: context.rh(12)),
              QuotationAgreementChips(agreements: agreements),
            ],
            if (warnings.isNotEmpty) ...[
              SizedBox(height: context.rh(12)),
              QuotationWarningsPanel(warnings: warnings),
            ],
            SizedBox(height: context.rh(16)),
            const DashedDivider(),
            SizedBox(height: context.rh(16)),
            QuotationItemsTable(
              items: items,
              isEditable: isEditable,
              currency: currency,
              onEditPrice:
                  onEditPrice ?? (item) => _handleEditPrice(context, item),
              onEditDiscount: onEditDiscount,
            ),
            SizedBox(height: context.rh(8)),
            const DashedDivider(),
            SizedBox(height: context.rh(14)),
            QuotationPreviewTotals(
              items: items,
              subtotal: subtotal,
              discount: discount,
              tax: tax,
              total: total,
              invoiceDiscounts: invoiceDiscounts,
              isTaxApplicable: isTaxApplicable,
              currency: currency,
            ),
            SizedBox(height: context.rh(14)),
            const DashedDivider(),
            SizedBox(height: context.rh(12)),
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
