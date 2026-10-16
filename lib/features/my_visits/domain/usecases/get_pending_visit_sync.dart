import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';

class GetPendingVisitSync extends UseCase<PendingVisitSync, NoParams> {
  const GetPendingVisitSync(this._repository);
  final VisitSyncRepository _repository;
  @override
  ResultFuture<PendingVisitSync> call(NoParams params) =>
      _repository.fetchPendingVisits();
}
