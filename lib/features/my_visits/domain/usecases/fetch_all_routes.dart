import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';

/// One-shot read of every locally-synced route (all days). Used by the Stop
/// Dashboard to re-read after a sync reports success, since sync writes through
/// the local data source and the live watch stream doesn't observe it.
class FetchAllRoutes extends UseCase<List<RoutePlan>, NoParams> {
  const FetchAllRoutes(this._repository);
  final RouteRepository _repository;

  @override
  ResultFuture<List<RoutePlan>> call(NoParams params) =>
      _repository.fetchAllRoutes();
}
