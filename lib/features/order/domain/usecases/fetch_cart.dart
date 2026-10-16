import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';

class FetchCart extends UseCase<List<CartItem>, NoParams> {
  const FetchCart(this._repository);
  final CartRepository _repository;

  @override
  ResultFuture<List<CartItem>> call(NoParams params) => _repository.fetchCart();
}
