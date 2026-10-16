import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';

class UpdateStopStatus extends UseCase<void, UpdateStopStatusParams> {
  const UpdateStopStatus(this._repository);
  final RouteRepository _repository;
  @override
  ResultFuture<void> call(UpdateStopStatusParams params) =>
      _repository.updateStopStatus(
        params.stopId,
        status: params.status,
        actualArrival: params.actualArrival,
        actualDeparture: params.actualDeparture,
      );
}
