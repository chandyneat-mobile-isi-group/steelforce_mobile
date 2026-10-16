import 'package:equatable/equatable.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart' show ResultFuture;
import 'package:steelforce/features/order/domain/entities/order_line_validation.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';

class ValidateOrderLineParams extends Equatable {
  const ValidateOrderLineParams({
    required this.skuId,
    required this.quantity,
    this.alreadyInCart = 0,
  });

  /// `products.id` — the exact SKU, warehouse included.
  final String skuId;

  /// What the rep is asking for *in total* for this line, not the delta.
  final double quantity;

  /// Units of this same SKU already committed on other lines of the same cart
  /// (a customized line and a plain line draw on the same warehouse stock).
  /// Counted against availability so two lines cannot each pass on their own
  /// and together over-commit the warehouse.
  final double alreadyInCart;

  @override
  List<Object?> get props => [skuId, quantity, alreadyInCart];
}

/// Decides whether a requested SKU + quantity may enter the cart.
///
/// ## What this deliberately no longer checks
///
/// **Stock.** Material selection is independent of stock: a rep may put any
/// catalogue material on a quotation, and availability is settled later in the
/// workflow. Two rules were removed for that reason:
///
///  * `!sku.isAvailable` — refused a line outright when the last sync happened
///    to show nothing on hand;
///  * `quantity > availableQuantity` — refused any quantity above the synced
///    figure, which for a material from the selection API is `0`, because that
///    API supplies no on-hand quantity at all. Every line above zero failed,
///    and the rep saw "Only 0 available at ." for a perfectly orderable
///    material.
///
/// What remains is the one rule that is not about stock: a line must ask for a
/// positive quantity. A SKU that no longer resolves is still reported, because
/// that is an identity problem rather than an availability one.
class ValidateOrderLine
    extends UseCase<OrderLineValidation, ValidateOrderLineParams> {
  const ValidateOrderLine(this._products);

  final ProductRepository _products;

  @override
  ResultFuture<OrderLineValidation> call(ValidateOrderLineParams params) async {
    if (params.quantity <= 0) {
      return Success(OrderLineValidation(
        issue: OrderLineIssue.nonPositiveQuantity,
        requestedQuantity: params.quantity,
        availableQuantity: 0,
        isStockStale: true,
      ));
    }

    final result = await _products.getProduct(params.skuId);
    return result.when(
      success: (product) => Success(_verdict(product, params)),
      // A SKU that no longer resolves is unavailable, not an error the rep
      // should see as a crash — it is the deleted/re-keyed material case.
      failure: (f) => f is CacheFailure
          ? Success(OrderLineValidation(
              issue: OrderLineIssue.skuUnavailable,
              requestedQuantity: params.quantity,
              availableQuantity: 0,
              isStockStale: true,
            ))
          : Failed(f),
    );
  }

  OrderLineValidation _verdict(Product sku, ValidateOrderLineParams params) {
    // The SKU resolved and the quantity is positive, so the line stands. The
    // available figure is still reported for anything that wants to *show* it;
    // nothing here refuses on it.
    return OrderLineValidation.valid(
      requestedQuantity: params.quantity,
      availableQuantity: sku.availableQuantity,
      isStockStale: true,
    );
  }
}

/// Convenience for callers that already hold a freshly-read [Product] and only
/// need the rule, not the round-trip — the product grid re-renders on every
/// cart change and must not fire a database read per card.
///
/// Stock is not consulted here either; see [ValidateOrderLine].
OrderLineValidation validateAgainstSku({
  required Product sku,
  required double quantity,
  double alreadyInCart = 0,
}) {
  if (quantity <= 0) {
    return OrderLineValidation(
      issue: OrderLineIssue.nonPositiveQuantity,
      requestedQuantity: quantity,
      availableQuantity: sku.availableQuantity,
      isStockStale: true,
    );
  }
  return OrderLineValidation.valid(
    requestedQuantity: quantity,
    availableQuantity: sku.availableQuantity,
    isStockStale: true,
  );
}
