import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class AddVisitNote extends UseCase<void, VisitNote> {
  const AddVisitNote(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<void> call(VisitNote params) => _repository.addNote(params);
}
