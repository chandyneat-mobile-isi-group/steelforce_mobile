import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/cart_items_table.dart';
import 'package:steelforce/core/utils/typedefs.dart';

part 'cart_dao.g.dart';

/// Scoped accessor for the local cart. Reads return raw [DataMap] rows (via
/// `customSelect`, snake_case columns) so the cart repository's existing
/// row contract is preserved verbatim; writes take typed companions.
@DriftAccessor(tables: [CartItems])
class CartDao extends DatabaseAccessor<AppDatabase> with _$CartDaoMixin {
  CartDao(super.db);

  Future<List<DataMap>> fetchRows() async {
    final rows = await customSelect(
      'SELECT * FROM cart_items ORDER BY created_at ASC',
      readsFrom: {cartItems},
    ).get();
    return rows.map((r) => r.data).toList();
  }

  Future<void> upsert(CartItemsCompanion item) =>
      into(cartItems).insertOnConflictUpdate(item);

  Future<void> remove(String id) =>
      (delete(cartItems)..where((t) => t.id.equals(id))).go();

  Future<void> clear() => delete(cartItems).go();

  /// Clears the cart and inserts [items] in a single transaction.
  Future<void> replace(List<CartItemsCompanion> items) async {
    await transaction(() async {
      await delete(cartItems).go();
      await batch((b) => b.insertAll(cartItems, items));
    });
  }
}
