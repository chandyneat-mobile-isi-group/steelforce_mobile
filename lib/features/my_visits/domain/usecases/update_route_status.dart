import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';

class UpdateRouteStatus extends UseCase<void, UpdateRouteStatusParams> {
  const UpdateRouteStatus(this._repository);
  final RouteRepository _repository;
  @override
  ResultFuture<void> call(UpdateRouteStatusParams params) =>
      _repository.updateRouteStatus(params.routeId, params.status);
}
