import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';
import 'package:steelforce/features/order/practice/order_practice_data.dart';

/// A practice cart held in [OrderPracticeData].
///
/// The rep's real cart — possibly a half-built quotation they will come back
/// to after the lesson — is neither read nor written: practice starts on an
/// empty cart and the real one is exactly where it was when practice ends.
/// Once [PracticeWorld.isClosed] every call goes to [_real].
class PracticeCartRepository implements CartRepository {
  PracticeCartRepository({
    required CartRepository real,
    required PracticeWorld world,
    required OrderPracticeData data,
  })  : _real = real,
        _world = world,
        _data = data;

  final CartRepository _real;
  final PracticeWorld _world;
  final OrderPracticeData _data;

  bool get _live => _world.isClosed;

  @override
  ResultFuture<List<CartItem>> fetchCart() async {
    if (_live) return _real.fetchCart();
    return Success(List.unmodifiable(_data.cart));
  }

  @override
  ResultFuture<void> addItem(CartItem item) async {
    if (_live) return _real.addItem(item);
    _upsert(item);
    return const Success(null);
  }

  @override
  ResultFuture<void> updateItem(CartItem item) async {
    if (_live) return _real.updateItem(item);
    _upsert(item);
    return const Success(null);
  }

  @override
  ResultFuture<void> removeItem(String cartItemId) async {
    if (_live) return _real.removeItem(cartItemId);
    _data.cart.removeWhere((i) => i.id == cartItemId);
    return const Success(null);
  }

  @override
  ResultFuture<void> clearCart() async {
    if (_live) return _real.clearCart();
    _data.cart.clear();
    return const Success(null);
  }

  @override
  ResultFuture<void> replaceCartWith(List<CartItem> items,
      {String? editingQuotationId}) async {
    if (_live) {
      return _real.replaceCartWith(items,
          editingQuotationId: editingQuotationId);
    }
    _data.cart
      ..clear()
      ..addAll(items);
    return const Success(null);
  }

  /// Insert-or-replace by line id, the `cart_items` table's own rule.
  void _upsert(CartItem item) {
    final index = _data.cart.indexWhere((i) => i.id == item.id);
    if (index < 0) {
      _data.cart.add(item);
    } else {
      _data.cart[index] = item;
    }
  }
}
