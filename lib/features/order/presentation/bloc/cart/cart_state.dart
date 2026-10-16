import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';

const cartTaxRate = 0.10;

sealed class CartState extends Equatable {
  const CartState();
  @override
  List<Object?> get props => [];
}

final class CartLoading extends CartState {
  const CartLoading();
}

final class CartLoaded extends CartState {
  const CartLoaded({required this.items});
  final List<CartItem> items;

  double get subtotal =>
      items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);
  double get discount =>
      items.fold<double>(0, (sum, i) => sum + i.lineDiscount);
  double get taxableAmount => subtotal - discount;
  double get tax => taxableAmount * cartTaxRate;
  double get total => taxableAmount + tax;
  int get itemCount => items.length;

  @override
  List<Object?> get props => [items];
}

final class CartError extends CartState {
  const CartError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
