import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/category.dart';
import 'package:steelforce/features/order/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl(this._local);
  final ProductLocalDataSource _local;

  @override
  ResultFuture<List<Category>> fetchAll() async {
    try {
      return Success(await _local.fetchCategories());
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }
}
