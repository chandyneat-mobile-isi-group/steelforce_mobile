import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';

class AddToCart extends UseCase<void, CartItem> {
  const AddToCart(this._repository);
  final CartRepository _repository;

  @override
  ResultFuture<void> call(CartItem params) => _repository.addItem(params);
}
