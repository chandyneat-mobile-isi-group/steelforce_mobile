import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class ToggleFavorite extends UseCase<void, ProductIdParams> {
  const ToggleFavorite(this._repository);
  final ProductRepository _repository;

  @override
  ResultFuture<void> call(ProductIdParams params) =>
      _repository.toggleFavorite(params.productId);
}
