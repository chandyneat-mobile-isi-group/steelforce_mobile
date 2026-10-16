import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/category.dart';

abstract interface class CategoryRepository {
  ResultFuture<List<Category>> fetchAll();
}
