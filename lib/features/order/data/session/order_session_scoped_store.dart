import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';

/// Drops the outgoing rep's working quotation on sign-out.
///
/// The cart is a draft quotation keyed to whoever is signed in — it carries
/// their depot/lead context and their pricing. Leaving it behind means the
/// next rep on the same device opens Orders to someone else's half-built
/// quotation and can save it under their own name.
///
/// Saved quotations and sales orders go with the rest of the database
/// (`LocalDatabaseSessionStore`); sign-out is refused while any of them is
/// still waiting to reach the server (`QuotationUnsentWorkSource`).
class OrderSessionScopedStore implements SessionScopedStore {
  const OrderSessionScopedStore(this._cart);

  final CartRepository _cart;

  @override
  String get debugName => 'order.cart';

  @override
  Future<void> clearForSignOut() => _cart.clearCart();
}
