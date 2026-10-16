import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/sync_result.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';
import 'package:steelforce/features/order/domain/repositories/sync_repository.dart';

class RunInitialSync extends UseCase<SyncResult, SyncScope> {
  const RunInitialSync(this._repository);
  final SyncRepository _repository;

  @override
  ResultFuture<SyncResult> call(SyncScope params) =>
      _repository.runInitialSync(params);
}
