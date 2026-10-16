import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class GetProductsByCategory
    extends UseCase<PagedResult<Product>, CategoryPageParams> {
  const GetProductsByCategory(this._repository);
  final ProductRepository _repository;

  @override
  ResultFuture<PagedResult<Product>> call(CategoryPageParams params) =>
      _repository.getProductsByCategory(
        categoryId: params.categoryId,
        page: params.page,
        pageSize: params.pageSize,
      );
}
