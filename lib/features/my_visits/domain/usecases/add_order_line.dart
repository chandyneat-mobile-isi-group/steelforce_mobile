import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class AddOrderLine extends UseCase<void, VisitOrderLine> {
  const AddOrderLine(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<void> call(VisitOrderLine params) =>
      _repository.addOrderLine(params);
}
