import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';

class FetchTodayRoutes extends UseCase<List<RoutePlan>, NoParams> {
  const FetchTodayRoutes(this._repository);
  final RouteRepository _repository;
  @override
  ResultFuture<List<RoutePlan>> call(NoParams params) =>
      _repository.fetchTodayRoutes();
}
