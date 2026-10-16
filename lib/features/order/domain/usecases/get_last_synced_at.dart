import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/sync_repository.dart';

class GetLastSyncedAt extends UseCase<DateTime?, NoParams> {
  const GetLastSyncedAt(this._repository);
  final SyncRepository _repository;

  @override
  ResultFuture<DateTime?> call(NoParams params) => _repository.lastSyncedAt();
}
