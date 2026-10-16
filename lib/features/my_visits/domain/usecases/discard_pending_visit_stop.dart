import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stop_discard.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';

/// The rep's **Discard** on a visit in the Sync Center: throws away
/// everything recorded at the stop that has not reached the server and puts
/// the stop back so the visit can be done again.
///
/// Spans two repositories, like `GetResumableRoute`: the discard is one
/// transaction in [VisitSyncRepository], and [RouteRepository] then tells the
/// open stop list, which only refreshes on its own writes, that a stop moved.
class DiscardPendingVisitStop extends UseCase<VisitStopDiscard, StopIdParams> {
  const DiscardPendingVisitStop(this._visitSync, this._routes);

  final VisitSyncRepository _visitSync;
  final RouteRepository _routes;

  @override
  ResultFuture<VisitStopDiscard> call(StopIdParams params) async {
    final result = await _visitSync.discardPendingStop(params.stopId);
    if (result case Success(data: final discard)
        when discard.reset != VisitStopReset.unchanged) {
      await _routes.notifyStopsChanged();
    }
    return result;
  }
}
