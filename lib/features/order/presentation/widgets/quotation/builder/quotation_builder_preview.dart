import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_state.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_totals.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_preview_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/manual_discount_input_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_preview_section.dart';

/// The live quotation summary at the foot of the builder: the cart's lines
/// with the server's totals, approval level, warnings and agreements, and the
/// per-line discount editor that writes to both the cart and the server draft.
class QuotationBuilderPreview extends StatelessWidget {
  const QuotationBuilderPreview({
    super.key,
    required this.depot,
    required this.leadDisplayName,
    required this.effectiveQuotationId,
    required this.isTaxApplicable,
    required this.onEditPrice,
  });

  final Depot? depot;
  final String? leadDisplayName;
  final String? effectiveQuotationId;
  final bool isTaxApplicable;
  final Future<void> Function(CartItem item) onEditPrice;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuotationBuilderCubit, QuotationBuilderState>(
      builder: (context, builderState) {
        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) =>
              _preview(context, builderState, cartState),
        );
      },
    );
  }

  Widget _preview(
    BuildContext context,
    QuotationBuilderState builderState,
    CartState cartState,
  ) {
    final cartItems =
        cartState is CartLoaded ? cartState.items : const <CartItem>[];
    final ready = builderState is QuotationBuilderReady ? builderState : null;
    final totals = QuotationBuilderTotals.resolve(
      builderState,
      cartState,
      isTaxApplicable: isTaxApplicable,
    );
    final agreements = ready?.agreements ?? const <DepotAgreement>[];
    final displayShopName = depot?.shopName ??
        leadDisplayName ??
        'orders.quotation_extra.walk_in'.tr;

    return QuotationPreviewSection(
      shopName: displayShopName,
      items: cartItems,
      subtotal: totals.subtotal,
      discount: totals.discount,
      tax: totals.tax,
      total: totals.total,
      currency: totals.currency,
      isEstimate: totals.isEstimate,
      requiredApprovalLevel: ready?.requiredApprovalLevel ?? 0,
      warnings: ready?.warnings ?? const <QuotationWarning>[],
      agreements: agreements,
      isTaxApplicable: isTaxApplicable,
      onEditDiscount: (item) => _editDiscount(context, item, ready, agreements),
      onEditPrice: onEditPrice,
      onEnlargeTap: cartItems.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<CartCubit>(),
                    child: QuotationScreen(
                      shopName: displayShopName,
                      subtotal: totals.subtotal,
                      discount: totals.discount,
                      tax: totals.tax,
                      total: totals.total,
                      items: cartItems,
                      isTaxApplicable: isTaxApplicable,
                      currency: totals.currency,
                      quotationNumber:
                          ready?.quotation.number ?? effectiveQuotationId,
                      depotPhone: depot?.phone,
                      depotAddress: depot?.address,
                    ),
                  ),
                ),
              ),
    );
  }

  /// The cart holds the rep's discount; the server draft, when there is one,
  /// is told the same so its totals and approval level follow.
  Future<void> _editDiscount(
    BuildContext context,
    CartItem item,
    QuotationBuilderReady? ready,
    List<DepotAgreement> agreements,
  ) async {
    final cartCubit = context.read<CartCubit>();
    final builderCubit = context.read<QuotationBuilderCubit>();
    final newPercent = await showManualDiscountInputSheet(
      context: context,
      item: item,
      currentDiscountPercent: item.discountPercent,
      maxDiscountPercent: ready?.manualDiscountLimit ?? 10.0,
      agreements: agreements,
      suggestedChips: ready?.discountAuthority?.suggestedChips,
    );
    if (newPercent == null || !context.mounted) return;

    await cartCubit.updateDiscount(item.id, newPercent);

    if (ready == null) return;
    final line = ready.lineForMaterial(item.product.materialNumber);
    if (line != null) {
      await builderCubit.setDiscounts([
        QuotationDiscountIntent(lineId: line.id, percent: newPercent),
      ]);
    }
  }
}
