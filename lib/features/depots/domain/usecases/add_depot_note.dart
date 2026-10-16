import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';

class AddDepotNote extends UseCase<void, AddDepotNoteParams> {
  const AddDepotNote(this._repository);
  final DepotRepository _repository;

  @override
  ResultFuture<void> call(AddDepotNoteParams params) =>
      _repository.addNote(params.depotId, params.body);
}
