import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';

/// Step 0 of the guided flow: the only thing loaded when the configurator
/// opens.
class FetchFilterCategories extends UseCase<List<MaterialCategory>, NoParams> {
  const FetchFilterCategories(this._repository);
  final ProductFilterRepository _repository;

  @override
  ResultFuture<List<MaterialCategory>> call(NoParams params) =>
      _repository.getFilterCategories();
}
