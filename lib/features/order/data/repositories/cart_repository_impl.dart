import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/cart_local_data_source.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/fulfillment.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';
import 'package:steelforce/features/order/domain/services/product_customization_spec.dart';

/// Composes [CartLocalDataSource] (`cart_items` table) with
/// [ProductLocalDataSource] to rehydrate full [CartItem]s — product-joining
/// logic isn't duplicated here.
class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(
      {required CartLocalDataSource cartLocal,
      required ProductLocalDataSource productLocal})
      : _cartLocal = cartLocal,
        _productLocal = productLocal;

  final CartLocalDataSource _cartLocal;
  final ProductLocalDataSource _productLocal;

  @override
  ResultFuture<List<CartItem>> fetchCart() async {
    try {
      return Success(await _hydrateCartRows(await _cartLocal.fetchCartRows()));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addItem(CartItem item) => _saveItem(item);

  @override
  ResultFuture<void> updateItem(CartItem item) => _saveItem(item);

  ResultFuture<void> _saveItem(CartItem item) async {
    try {
      await _cartLocal.upsertItem(_toRow(item));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> removeItem(String cartItemId) async {
    try {
      await _cartLocal.removeItem(cartItemId);
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> clearCart() async {
    try {
      await _cartLocal.clearCart();
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> replaceCartWith(List<CartItem> items,
      {String? editingQuotationId}) async {
    try {
      await _cartLocal.replaceCart([
        for (final item in items)
          _toRow(item, editingQuotationId: editingQuotationId)
      ]);
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  DataMap _toRow(CartItem item, {String? editingQuotationId}) => {
        'id': item.id,
        'product_id': item.product.id,
        'quantity': item.quantity,
        'unit': item.unit,
        'discount_percent': item.discountPercent,
        'lead_id': item.leadId,
        'depot_id': item.depotId,
        'editing_quotation_id': editingQuotationId,
        'customization_json': ProductCustomizationSpec.encode(item),
        // `unitPrice`, not `unitPriceOverride`: a line entering the cart from
        // the product grid never carried an explicit override, and writing the
        // resolved figure is what freezes it against the next catalog sync.
        'unit_price': item.unitPrice,
        'fulfillment_json': ShipmentSelection.encode(item.fulfillment),
        'created_at': DateTime.now().toIso8601String(),
      };

  Future<List<CartItem>> _hydrateCartRows(List<DataMap> rows) async {
    final items = <CartItem>[];
    for (final row in rows) {
      final product = await _productLocal.getById(row['product_id'] as String);
      if (product == null) continue;
      final base = CartItem(
        id: row['id'] as String,
        product: product,
        quantity: (row['quantity'] as num).toDouble(),
        unit: row['unit'] as String,
        discountPercent: (row['discount_percent'] as num).toDouble(),
        leadId: row['lead_id'] as String?,
        depotId: row['depot_id'] as String?,
        // Null on rows written before v17, which falls back to the live
        // catalog price — what those rows always did.
        unitPriceOverride: (row['unit_price'] as num?)?.toDouble(),
        fulfillment:
            ShipmentSelection.decode(row['fulfillment_json'] as String?),
      );
      items.add(ProductCustomizationSpec.applyEncoded(
          base, row['customization_json'] as String?));
    }
    return items;
  }
}
