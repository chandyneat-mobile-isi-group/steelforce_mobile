import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_push_summary.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';

class PushPendingVisitData extends UseCase<VisitPushSummary, NoParams> {
  const PushPendingVisitData(this._repository);
  final VisitSyncRepository _repository;
  @override
  ResultFuture<VisitPushSummary> call(NoParams params) =>
      _repository.pushPendingVisitData();
}
