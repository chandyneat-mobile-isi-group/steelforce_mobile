import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';

class UpdateCartItem extends UseCase<void, CartItem> {
  const UpdateCartItem(this._repository);
  final CartRepository _repository;

  @override
  ResultFuture<void> call(CartItem params) => _repository.updateItem(params);
}
