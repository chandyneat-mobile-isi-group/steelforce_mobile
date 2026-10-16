import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class AddStockUpdate extends UseCase<void, VisitStockUpdate> {
  const AddStockUpdate(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<void> call(VisitStockUpdate params) =>
      _repository.addStockUpdate(params);
}
