import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';

class ClearCart extends UseCase<void, NoParams> {
  const ClearCart(this._repository);
  final CartRepository _repository;

  @override
  ResultFuture<void> call(NoParams params) => _repository.clearCart();
}
