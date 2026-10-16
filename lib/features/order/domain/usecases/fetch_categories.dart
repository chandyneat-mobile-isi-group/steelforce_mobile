import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/category.dart';
import 'package:steelforce/features/order/domain/repositories/category_repository.dart';

class FetchCategories extends UseCase<List<Category>, NoParams> {
  const FetchCategories(this._repository);
  final CategoryRepository _repository;

  @override
  ResultFuture<List<Category>> call(NoParams params) => _repository.fetchAll();
}
