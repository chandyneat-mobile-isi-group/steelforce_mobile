import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class AddReturn extends UseCase<void, VisitReturn> {
  const AddReturn(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<void> call(VisitReturn params) => _repository.addReturn(params);
}
