import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';

/// Live stream of today's routes for the dashboard — emits the current local
/// snapshot immediately, then again on every change (check-in/out, sync).
class WatchTodayRoutes extends StreamUseCase<List<RoutePlan>, NoParams> {
  const WatchTodayRoutes(this._repository);
  final RouteRepository _repository;

  @override
  Stream<List<RoutePlan>> call(NoParams params) =>
      _repository.watchTodayRoutes();
}
