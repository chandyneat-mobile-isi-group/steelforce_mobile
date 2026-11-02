import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';
import 'package:steelforce/features/my_visits/domain/repositories/pending_plan_visits_source.dart';

/// Planned visits whose check-in, photos or check-out wait on this device.
class WatchPendingPlanVisits
    extends StreamUseCase<List<PendingPlanVisit>, NoParams> {
  const WatchPendingPlanVisits(this._source);
  final PendingPlanVisitsSource _source;

  @override
  Stream<List<PendingPlanVisit>> call(NoParams params) => _source.watch();
}
