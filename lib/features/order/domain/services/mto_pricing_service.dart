import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/mto_quote.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';

/// Kept structurally separate from [ProductRepository]'s local price
/// resolution: standard products always resolve from the cached `prices`
/// table, made-to-order products always go through here instead — today a
/// mock that simulates an online SAP quote request, swappable later without
/// touching the UI.
abstract interface class MtoPricingService {
  ResultFuture<MtoQuote> requestQuote(Product product);
}
