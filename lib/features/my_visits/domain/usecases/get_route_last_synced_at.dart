import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_sync_repository.dart';

class GetRouteLastSyncedAt extends UseCase<DateTime?, NoParams> {
  const GetRouteLastSyncedAt(this._repository);
  final RouteSyncRepository _repository;
  @override
  ResultFuture<DateTime?> call(NoParams params) => _repository.lastSyncedAt();
}
