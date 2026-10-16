import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class RemoveFromCart extends UseCase<void, CartItemIdParams> {
  const RemoveFromCart(this._repository);
  final CartRepository _repository;

  @override
  ResultFuture<void> call(CartItemIdParams params) =>
      _repository.removeItem(params.cartItemId);
}
