import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class AddVisitPhoto extends UseCase<void, VisitPhoto> {
  const AddVisitPhoto(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<void> call(VisitPhoto params) => _repository.addPhoto(params);
}
