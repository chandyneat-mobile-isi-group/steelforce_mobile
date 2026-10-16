import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class AddCollection extends UseCase<void, VisitCollection> {
  const AddCollection(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<void> call(VisitCollection params) =>
      _repository.addCollection(params);
}
