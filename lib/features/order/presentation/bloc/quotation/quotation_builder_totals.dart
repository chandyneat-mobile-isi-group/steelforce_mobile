import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_state.dart';

/// The figures the builder shows and saves.
///
/// The server's totals whenever it has priced the draft — the cardinal rule is
/// that the client computes nothing it can be told. Only before the first
/// preview answers does the cart stand in, as an on-device estimate.
class QuotationBuilderTotals {
  const QuotationBuilderTotals._({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.currency,
    required this.isEstimate,
  });

  factory QuotationBuilderTotals.resolve(
    QuotationBuilderState builderState,
    CartState cartState, {
    required bool isTaxApplicable,
  }) {
    final server = builderState is QuotationBuilderReady
        ? builderState.effectiveTotals
        : null;
    final cart = cartState is CartLoaded ? cartState : null;

    final subtotal = server?.gross ?? cart?.subtotal ?? 0.0;
    final discount = server?.discountTotal ?? cart?.discount ?? 0.0;
    final taxable = (subtotal - discount).clamp(0.0, double.infinity);
    final tax = server?.tax ?? (isTaxApplicable ? taxable * cartTaxRate : 0.0);

    return QuotationBuilderTotals._(
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: server?.net ?? (taxable + tax),
      currency: server?.currency ?? 'USD',
      isEstimate: server?.isEstimate ?? false,
    );
  }

  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String currency;
  final bool isEstimate;
}
