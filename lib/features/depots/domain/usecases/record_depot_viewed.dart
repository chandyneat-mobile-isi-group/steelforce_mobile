import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';

class RecordDepotViewed extends UseCase<void, DepotIdParams> {
  const RecordDepotViewed(this._repository);
  final DepotRepository _repository;

  @override
  ResultFuture<void> call(DepotIdParams params) =>
      _repository.recordViewed(params.depotId);
}
