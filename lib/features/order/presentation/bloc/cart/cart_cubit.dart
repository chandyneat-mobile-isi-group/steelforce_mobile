import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/data_domain.dart'
    show CustomizationMeasurement;
import 'package:steelforce/features/order/domain/entities/fulfillment.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/usecases/add_to_cart.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/clear_cart.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_cart.dart';
import 'package:steelforce/features/order/domain/usecases/remove_from_cart.dart';
import 'package:steelforce/features/order/domain/usecases/replace_cart.dart';
import 'package:steelforce/features/order/domain/usecases/save_quotation.dart';
import 'package:steelforce/features/order/domain/usecases/update_cart_item.dart';
import 'package:steelforce/features/order/domain/usecases/update_quotation.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';

/// Persists to the `cart_items` table on every mutation (via the repository)
/// so the cart survives app restarts, while keeping in-memory state as the
/// source of truth for the UI — the same optimistic-update shape used by
/// `PipelineBloc` elsewhere in the app.
class CartCubit extends Cubit<CartState> {
  CartCubit({
    required FetchCart fetchCart,
    required AddToCart addToCart,
    required UpdateCartItem updateCartItem,
    required RemoveFromCart removeFromCart,
    required ClearCart clearCart,
    required ReplaceCart replaceCart,
    required SaveQuotation saveQuotation,
    required UpdateQuotation updateQuotation,
  })  : _fetchCart = fetchCart,
        _addToCart = addToCart,
        _updateCartItem = updateCartItem,
        _removeFromCart = removeFromCart,
        _clearCart = clearCart,
        _replaceCart = replaceCart,
        _saveQuotation = saveQuotation,
        _updateQuotation = updateQuotation,
        super(const CartLoading());

  final FetchCart _fetchCart;
  final AddToCart _addToCart;
  final UpdateCartItem _updateCartItem;
  final RemoveFromCart _removeFromCart;
  final ClearCart _clearCart;
  final ReplaceCart _replaceCart;
  final SaveQuotation _saveQuotation;
  final UpdateQuotation _updateQuotation;

  List<CartItem> get _items =>
      state is CartLoaded ? (state as CartLoaded).items : const [];

  Future<void> load() async {
    final result = await _fetchCart(const NoParams());
    result.when(
      success: (items) => emit(CartLoaded(items: items)),
      failure: (f) => emit(CartError(f.message)),
    );
  }

  /// Adds [product] — one exact SKU, warehouse included, since a `products`
  /// row *is* a SKU — to the cart.
  ///
  /// [unitPrice] freezes what this line was sold at; leaving it null prices the
  /// line from the live catalog, which is what the product-grid stepper does.
  /// [fulfillment] carries the pickup/delivery terms when the line came through
  /// the key-in sheet.
  Future<void> addProduct(Product product,
      {double quantity = 1,
      String? unit,
      String? leadId,
      String? depotId,
      double? unitPrice,
      bool isManualPrice = false,
      double discountPercent = 0,
      ShipmentSelection? fulfillment}) async {
    // Duplicate lines merge only when the same SKU is added on the same
    // commercial terms. Unit was already part of that rule (Pc vs Ton is a
    // distinct line); fulfillment now is too, because the same SKU picked up
    // at the factory and delivered to site are two order lines with different
    // logistics, not one line with twice the quantity.
    final lineUnit = unit ?? product.unit;
    CartItem? existing;
    for (final item in _items) {
      if (item.product.id == product.id &&
          item.unit == lineUnit &&
          item.leadId == leadId &&
          item.depotId == depotId &&
          item.fulfillment == fulfillment) {
        existing = item;
      }
    }

    if (existing != null) {
      final updated = existing.copyWith(quantity: existing.quantity + quantity);
      emit(CartLoaded(items: [
        for (final i in _items)
          if (i.id == existing.id) updated else i
      ]));
      await _updateCartItem(updated);
    } else {
      final newItem = CartItem(
        id: _newId(),
        product: product,
        quantity: quantity,
        unit: lineUnit,
        discountPercent: discountPercent,
        leadId: leadId,
        depotId: depotId,
        unitPriceOverride: unitPrice,
        isManualPrice: isManualPrice,
        fulfillment: fulfillment,
      );
      emit(CartLoaded(items: [..._items, newItem]));
      await _addToCart(newItem);
    }
  }

  /// Adds a customized line. Unlike [addProduct], a customized line is always
  /// its own row — two customizations of the same product never merge, because
  /// their measurements/appearance differ.
  Future<void> addCustomProduct(
    Product product, {
    required double quantity,
    required String unit,
    CustomizationMeasurement? measurements,
    String? appearance,
    String? drawingImagePath,
    String? customizationDescription,
    String? leadId,
    String? depotId,
  }) async {
    final newItem = CartItem(
      id: _newId(),
      product: product,
      quantity: quantity,
      unit: unit,
      discountPercent: 0,
      leadId: leadId,
      depotId: depotId,
      isCustomized: true,
      measurements: measurements,
      appearance: appearance,
      drawingImagePath: drawingImagePath,
      customizationDescription: customizationDescription,
    );
    emit(CartLoaded(items: [..._items, newItem]));
    await _addToCart(newItem);
  }

  Future<void> updateQuantity(String cartItemId, double quantity) async {
    if (quantity <= 0) return removeItem(cartItemId);
    final updated = [
      for (final i in _items)
        if (i.id == cartItemId) i.copyWith(quantity: quantity) else i
    ];
    emit(CartLoaded(items: updated));
    final item = updated.where((i) => i.id == cartItemId);
    if (item.isNotEmpty) await _updateCartItem(item.first);
  }

  Future<void> updateDiscount(String cartItemId, double discountPercent) async {
    final updated = [
      for (final i in _items)
        if (i.id == cartItemId)
          i.copyWith(discountPercent: discountPercent)
        else
          i,
    ];
    emit(CartLoaded(items: updated));
    final item = updated.where((i) => i.id == cartItemId);
    if (item.isNotEmpty) await _updateCartItem(item.first);
  }

  /// Sets a manual unit price override (default currency USD) for [cartItemId].
  ///
  /// Passing `null` or `<= 0` clears the override back to catalog / pending.
  Future<void> updateUnitPrice(
    String cartItemId,
    double? unitPrice, {
    bool isManualPrice = true,
  }) async {
    final updated = [
      for (final i in _items)
        if (i.id == cartItemId)
          i.copyWith(
            unitPriceOverride: () =>
                (unitPrice != null && unitPrice > 0) ? unitPrice : null,
            isManualPrice:
                (unitPrice != null && unitPrice > 0) ? isManualPrice : false,
          )
        else
          i,
    ];
    emit(CartLoaded(items: updated));
    final item = updated.where((i) => i.id == cartItemId);
    if (item.isNotEmpty) await _updateCartItem(item.first);
  }

  Future<void> removeItem(String cartItemId) async {
    emit(CartLoaded(items: _items.where((i) => i.id != cartItemId).toList()));
    await _removeFromCart(CartItemIdParams(cartItemId));
  }

  /// Seeds the cart wholesale from an existing [Quotation] — used by
  /// "Edit Quotation" and the Sales Order screen's conversion step.
  Future<void> loadFromQuotation(Quotation quotation) async {
    emit(CartLoaded(items: quotation.lines));
    await _replaceCart(ReplaceCartParams(
        items: quotation.lines, editingQuotationId: quotation.id));
  }

  /// Saves the current cart as a new [Quotation], or updates [editing] in
  /// place when re-saving from the Edit Quotation flow. Clears the cart on
  /// success either way.
  Future<Quotation?> saveQuotation({
    String? depotId,
    String? shopName,
    String? leadId,
    String? leadDisplayName,
    OffVisitReason? offVisitReason,
    double? gpsLat,
    double? gpsLng,
    Quotation? editing,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? remoteId,
  }) async {
    final items = _items;
    final result = editing == null
        ? await _saveQuotation(SaveQuotationParams(
            items: items,
            depotId: depotId,
            shopName: shopName,
            leadId: leadId,
            leadDisplayName: leadDisplayName,
            offVisitReason: offVisitReason,
            gpsLat: gpsLat,
            gpsLng: gpsLng,
            subtotal: subtotal,
            discount: discount,
            tax: tax,
            total: total,
            remoteId: remoteId,
          ))
        : await _updateQuotation(
            UpdateQuotationParams(
              existing: editing,
              items: items,
              subtotal: subtotal,
              discount: discount,
              tax: tax,
              total: total,
              remoteId: remoteId,
            ),
          );

    return result.when(
      success: (quotation) {
        emit(const CartLoaded(items: []));
        return quotation;
      },
      failure: (_) => null,
    );
  }

  Future<void> clear() async {
    emit(const CartLoaded(items: []));
    await _clearCart(const NoParams());
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';
}
