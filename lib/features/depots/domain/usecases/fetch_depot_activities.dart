import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';

class FetchDepotActivities extends UseCase<List<DepotActivity>, DepotIdParams> {
  const FetchDepotActivities(this._repository);
  final DepotRepository _repository;

  @override
  ResultFuture<List<DepotActivity>> call(DepotIdParams params) =>
      _repository.fetchActivities(params.depotId);
}
