import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_note.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';

class FetchDepotNotes extends UseCase<List<DepotNote>, DepotIdParams> {
  const FetchDepotNotes(this._repository);
  final DepotRepository _repository;

  @override
  ResultFuture<List<DepotNote>> call(DepotIdParams params) =>
      _repository.fetchNotes(params.depotId);
}
