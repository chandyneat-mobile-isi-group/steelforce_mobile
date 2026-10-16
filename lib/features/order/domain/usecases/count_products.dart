import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

/// Returns the exact number of products matching a query + filter. Reuses
/// [BrowseProductsParams] (page/pageSize are ignored) so the filter screen can
/// derive a count from the very same params it browses with.
class CountProducts extends UseCase<int, BrowseProductsParams> {
  const CountProducts(this._repository);
  final ProductRepository _repository;

  @override
  ResultFuture<int> call(BrowseProductsParams params) =>
      _repository.countProducts(query: params.query, filter: params.filter);
}
