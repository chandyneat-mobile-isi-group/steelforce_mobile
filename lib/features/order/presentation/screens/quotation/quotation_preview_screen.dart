import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/pdf/pdf_generation_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/pdf/pdf_generation_state.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_preview_section.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/discount_summary_section.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Full-screen quotation preview + PDF export entry point.
///
/// Owns a [PdfGenerationCubit] (from DI) so the "Download PDF" action runs
/// through the enterprise PDF pipeline — no PDF logic lives in this widget.
class QuotationScreen extends StatelessWidget {
  const QuotationScreen({
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
    this.quotationNumber,
    this.createdDate,
    this.validUntil,
    this.depotPhone,
    this.depotAddress,
    this.notes,
    this.onPDFDownload,
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

  /// Optional PDF metadata. Sensible defaults are derived when omitted, so
  /// existing callers keep working.
  final String? quotationNumber;
  final DateTime? createdDate;
  final DateTime? validUntil;
  final String? depotPhone;
  final String? depotAddress;
  final String? notes;

  /// Legacy hook kept for backward compatibility; the button now drives the
  /// [PdfGenerationCubit] directly, but if a caller still passes this it is
  /// invoked after a successful export.
  final VoidCallback? onPDFDownload;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PdfGenerationCubit>(
      create: (_) => sl<PdfGenerationCubit>(),
      child: _QuotationView(
        shopName: shopName,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        items: items,
        invoiceDiscounts: invoiceDiscounts,
        isTaxApplicable: isTaxApplicable,
        currency: currency,
        quotationNumber: quotationNumber,
        createdDate: createdDate,
        validUntil: validUntil,
        depotPhone: depotPhone,
        depotAddress: depotAddress,
        notes: notes,
        onPDFDownload: onPDFDownload,
      ),
    );
  }
}

class _QuotationView extends StatelessWidget {
  const _QuotationView({
    required this.shopName,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.items,
    this.invoiceDiscounts = const [],
    this.isTaxApplicable = true,
    this.currency = 'USD',
    required this.quotationNumber,
    required this.createdDate,
    required this.validUntil,
    required this.depotPhone,
    required this.depotAddress,
    required this.notes,
    required this.onPDFDownload,
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
  final String? quotationNumber;
  final DateTime? createdDate;
  final DateTime? validUntil;
  final String? depotPhone;
  final String? depotAddress;
  final String? notes;
  final VoidCallback? onPDFDownload;

  String _resolvedQuotationNumber() {
    if (quotationNumber != null && quotationNumber!.isNotEmpty) {
      return quotationNumber!;
    }
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'QT-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  void _download(
    BuildContext context, {
    required List<CartItem> activeItems,
    required double activeSubtotal,
    required double activeDiscount,
    required double activeTax,
    required double activeTotal,
  }) {
    final formattedInvoiceDiscounts = invoiceDiscounts.map((inv) {
      final rule = inv.rule.isNotEmpty ? ' (${inv.rule})' : '';
      return '${inv.name}$rule: -\$${inv.amount.toStringAsFixed(2)}';
    }).toList();

    final skuDiscountTotal = activeItems.fold<double>(
      0.0,
      (sum, item) => sum + item.lineDiscount,
    );
    final invoiceDiscountTotal = invoiceDiscounts.fold<double>(
      0.0,
      (sum, inv) => sum + inv.amount,
    );

    context.read<PdfGenerationCubit>().generateQuotationPdf(
          quotationNumber: _resolvedQuotationNumber(),
          // Khmer-safe: PDF values render through PdfShapedText, which shapes
          // Khmer via Flutter's text engine.
          depotName: shopName ?? 'orders.quotation_extra.walk_in'.tr,
          depotPhone: depotPhone,
          depotAddress: depotAddress,
          createdDate: createdDate ?? DateTime.now(),
          validUntil: validUntil ?? DateTime.now().add(const Duration(days: 7)),
          items: activeItems,
          subtotal: activeSubtotal,
          discount: activeDiscount,
          skuDiscountTotal: skuDiscountTotal,
          invoiceDiscountTotal: invoiceDiscountTotal,
          tax: activeTax,
          total: activeTotal,
          isTaxApplicable: isTaxApplicable,
          invoiceDiscounts: formattedInvoiceDiscounts,
          notes: notes,
        );
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    CartState? cartState;
    try {
      cartState = context.watch<CartCubit>().state;
    } catch (_) {}

    final activeItems = (cartState is CartLoaded) ? cartState.items : items;
    final activeSubtotal =
        (cartState is CartLoaded) ? cartState.subtotal : subtotal;
    final activeDiscount =
        (cartState is CartLoaded) ? cartState.discount : discount;
    final activeTaxable = activeSubtotal - activeDiscount;
    final activeTax = (cartState is CartLoaded)
        ? (activeTaxable * (isTaxApplicable ? 0.10 : 0.0))
        : tax;
    final activeTotal =
        (cartState is CartLoaded) ? (activeTaxable + activeTax) : total;

    return Scaffold(
      backgroundColor: themeColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(context.rw(16), context.rh(16),
                    context.rw(16), context.rh(8)),
                child: Column(
                  children: [
                    QuotationPreviewSection(
                      shopName: shopName,
                      subtotal: activeSubtotal,
                      discount: activeDiscount,
                      tax: activeTax,
                      total: activeTotal,
                      items: activeItems,
                      invoiceDiscounts: invoiceDiscounts,
                      isTaxApplicable: isTaxApplicable,
                      currency: currency,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rw(16), vertical: context.rh(12)),
              child: BlocConsumer<PdfGenerationCubit, PdfGenerationState>(
                listener: (context, state) {
                  if (state is PdfGenerated) {
                    onPDFDownload?.call();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          backgroundColor: themeColors.success,
                          content: Text('orders.quotation.pdf.success'.tr),
                        ),
                      );
                  } else if (state is PdfGenerationFailed) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          backgroundColor: colorScheme.error,
                          content: Text(state.messageKey.tr),
                        ),
                      );
                  }
                },
                builder: (context, state) {
                  final isGenerating = state is PdfGenerating;
                  return Row(
                    children: [
                      OutlinedButton(
                        onPressed:
                            isGenerating ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: context.rh(14),
                              horizontal: context.rw(24)),
                          side:
                              BorderSide(color: themeColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.rr(14)),
                          ),
                        ),
                        child: Text(
                          'common.back'.tr,
                          style: TextStyle(
                            fontSize: context.rsp(15),
                            fontWeight: FontWeight.bold,
                            color: themeColors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: context.rw(12)),
                      Expanded(
                        child: InkWell(
                          onTap: isGenerating
                              ? null
                              : () => _download(
                                    context,
                                    activeItems: activeItems,
                                    activeSubtotal: activeSubtotal,
                                    activeDiscount: activeDiscount,
                                    activeTax: activeTax,
                                    activeTotal: activeTotal,
                                  ),
                          borderRadius: BorderRadius.circular(context.rr(14)),
                          child: Container(
                            height: context.rh(52),
                            decoration: BoxDecoration(
                              color: isGenerating
                                  ? colorScheme.primary.withValues(alpha: 0.7)
                                  : colorScheme.primary,
                              borderRadius:
                                  BorderRadius.circular(context.rr(14)),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: isGenerating
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: context.rw(18),
                                        height: context.rw(18),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: context.rw(10)),
                                      Text(
                                        'orders.quotation.pdf.generating'.tr,
                                        style: TextStyle(
                                          fontSize: context.rsp(15),
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'orders.quotation.pdf.download'.tr,
                                    style: TextStyle(
                                      fontSize: context.rsp(15),
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
