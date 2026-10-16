import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';

/// Live stream of every locally-synced route regardless of date — backs the
/// dashboard's calendar (per-day route-count dots) and date-selection
/// browsing, neither of which [WatchTodayRoutes] can answer since it's
/// scoped to today only. Emits the current local snapshot immediately, then
/// again on every change (check-in/out, sync).
class WatchAllRoutes extends StreamUseCase<List<RoutePlan>, NoParams> {
  const WatchAllRoutes(this._repository);
  final RouteRepository _repository;

  @override
  Stream<List<RoutePlan>> call(NoParams params) => _repository.watchAllRoutes();
}
