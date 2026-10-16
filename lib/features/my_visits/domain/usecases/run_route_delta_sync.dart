import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_sync_repository.dart';

class RunRouteDeltaSync extends UseCase<RouteSyncResult, RouteSyncScope> {
  const RunRouteDeltaSync(this._repository);
  final RouteSyncRepository _repository;
  @override
  ResultFuture<RouteSyncResult> call(RouteSyncScope params) =>
      _repository.runDeltaSync(params);
}
