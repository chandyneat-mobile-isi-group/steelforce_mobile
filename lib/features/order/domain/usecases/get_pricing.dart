import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class GetPricing extends UseCase<double, PricingParams> {
  const GetPricing(this._repository);
  final ProductRepository _repository;

  @override
  ResultFuture<double> call(PricingParams params) =>
      _repository.getPricing(params.productId, params.tier);
}
