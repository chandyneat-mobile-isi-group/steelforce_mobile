import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class GetProductVariants extends UseCase<List<Product>, FamilyIdParams> {
  const GetProductVariants(this._repository);
  final ProductRepository _repository;

  @override
  ResultFuture<List<Product>> call(FamilyIdParams params) =>
      _repository.getProductVariants(params.familyId);
}
