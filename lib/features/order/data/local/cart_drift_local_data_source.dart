import 'package:drift/drift.dart' show Value;
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/cart_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/cart_local_data_source.dart';

/// [CartLocalDataSource] backed by the single encrypted Drift database (T5
/// cutover) via [CartDao]. The cart repository still speaks in raw [DataMap]
/// rows (snake_case columns); reads pass those through unchanged and writes
/// convert them into typed companions here.
class CartDriftLocalDataSource implements CartLocalDataSource {
  const CartDriftLocalDataSource(this._dao);

  final CartDao _dao;

  static CartItemsCompanion _toCompanion(DataMap row) {
    return CartItemsCompanion.insert(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      unit: row['unit'] as String,
      discountPercent:
          Value((row['discount_percent'] as num?)?.toDouble() ?? 0),
      leadId: Value(row['lead_id'] as String?),
      depotId: Value(row['depot_id'] as String?),
      editingQuotationId: Value(row['editing_quotation_id'] as String?),
      customizationJson: Value(row['customization_json'] as String?),
      unitPrice: Value((row['unit_price'] as num?)?.toDouble()),
      fulfillmentJson: Value(row['fulfillment_json'] as String?),
      createdAt: row['created_at'] as String,
    );
  }

  @override
  Future<List<DataMap>> fetchCartRows() async {
    try {
      return await _dao.fetchRows();
    } catch (e) {
      throw CacheException(message: 'Failed to load cart: $e');
    }
  }

  @override
  Future<void> upsertItem(DataMap row) async {
    try {
      await _dao.upsert(_toCompanion(row));
    } catch (e) {
      throw CacheException(message: 'Failed to save cart item: $e');
    }
  }

  @override
  Future<void> removeItem(String id) async {
    try {
      await _dao.remove(id);
    } catch (e) {
      throw CacheException(message: 'Failed to remove cart item: $e');
    }
  }

  @override
  Future<void> clearCart() async {
    try {
      await _dao.clear();
    } catch (e) {
      throw CacheException(message: 'Failed to clear cart: $e');
    }
  }

  @override
  Future<void> replaceCart(List<DataMap> rows) async {
    try {
      await _dao.replace(rows.map(_toCompanion).toList());
    } catch (e) {
      throw CacheException(message: 'Failed to replace cart: $e');
    }
  }
}
