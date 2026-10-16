import 'package:steelforce/core/utils/typedefs.dart';

/// Owns only the `cart_items` table — [CartRepositoryImpl] composes this with
/// [ProductLocalDataSource] to rehydrate full cart items, so product-joining
/// logic isn't duplicated here. Backed by the single encrypted Drift database
/// (see [CartDriftLocalDataSource]) after the T5 cutover.
abstract interface class CartLocalDataSource {
  Future<List<DataMap>> fetchCartRows();
  Future<void> upsertItem(DataMap row);
  Future<void> removeItem(String id);
  Future<void> clearCart();

  /// Clears `cart_items` and batch-inserts [rows] in one transaction — used to
  /// seed the cart from a `Quotation`/`SalesOrder` rather than one-by-one
  /// upserts.
  Future<void> replaceCart(List<DataMap> rows);
}
