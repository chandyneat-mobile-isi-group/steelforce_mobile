import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';

abstract interface class CartRepository {
  ResultFuture<List<CartItem>> fetchCart();
  ResultFuture<void> addItem(CartItem item);
  ResultFuture<void> updateItem(CartItem item);
  ResultFuture<void> removeItem(String cartItemId);
  ResultFuture<void> clearCart();

  /// Clears the cart and replaces it wholesale with [items] — used to seed
  /// the cart from an existing `Quotation`/`SalesOrder` (Edit Quotation,
  /// Sales Order conversion) rather than one-by-one `addItem` calls.
  /// [editingQuotationId], when set, tags every row so the in-progress edit
  /// survives an app restart.
  ResultFuture<void> replaceCartWith(List<CartItem> items,
      {String? editingQuotationId});
}
