import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';

class FetchBrands extends UseCase<List<String>, NoParams> {
  const FetchBrands(this._repository);
  final ProductRepository _repository;

  @override
  ResultFuture<List<String>> call(NoParams params) => _repository.fetchBrands();
}
