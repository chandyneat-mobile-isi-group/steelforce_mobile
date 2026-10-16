import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';

class GetRoute extends UseCase<RoutePlan, RouteIdParams> {
  const GetRoute(this._repository);
  final RouteRepository _repository;
  @override
  ResultFuture<RoutePlan> call(RouteIdParams params) =>
      _repository.getRoute(params.routeId);
}
