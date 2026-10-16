import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_visit_outcome.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';

/// Adds a depot the Call Plan missed to today's visits.
class AddAdHocVisit extends UseCase<AdHocVisitOutcome, AddAdHocVisitParams> {
  const AddAdHocVisit(this._repository);
  final AdHocVisitRepository _repository;

  @override
  ResultFuture<AdHocVisitOutcome> call(AddAdHocVisitParams params) =>
      _repository.add(
        depotId: params.depotId,
        sk: params.sk,
        depotName: params.depotName,
      );
}

class AddAdHocVisitParams extends Equatable {
  const AddAdHocVisitParams({
    required this.depotId,
    required this.sk,
    required this.depotName,
  });

  /// `Depot.id` from the directory. Not sent — used to route a 409 to the
  /// stop the rep already has.
  final String depotId;

  /// The depot's SAP code (`Depot.sapDepotId`), which the endpoint is keyed
  /// on. A depot SAP has not reported back has none and cannot be added; the
  /// entry points disable the action for it rather than letting it 404.
  final String sk;

  /// Shown on the pending row while the request is in flight. Never sent.
  final String depotName;

  @override
  List<Object?> get props => [depotId, sk, depotName];
}

/// Retries every ad hoc request that has not reached the server, reusing each
/// stored `clientRequestId` so a replay returns the original visit rather than
/// creating a second one.
class DrainAdHocVisitQueue extends UseCase<List<AdHocVisitOutcome>, NoParams> {
  const DrainAdHocVisitQueue(this._repository);
  final AdHocVisitRepository _repository;

  @override
  ResultFuture<List<AdHocVisitOutcome>> call(NoParams params) =>
      _repository.drainQueue();
}

/// The depot ids already on a given day, so the picker can hide them.
class GetDepotIdsOnDay extends UseCase<Set<String>, DateTime> {
  const GetDepotIdsOnDay(this._repository);
  final AdHocVisitRepository _repository;

  @override
  ResultFuture<Set<String>> call(DateTime params) =>
      _repository.depotIdsOnDay(params);
}

/// The ad hoc requests still waiting to be delivered.
class WatchPendingAdHocVisits
    extends StreamUseCase<List<PendingAdHocVisit>, NoParams> {
  const WatchPendingAdHocVisits(this._repository);
  final AdHocVisitRepository _repository;

  @override
  Stream<List<PendingAdHocVisit>> call(NoParams params) =>
      _repository.watchPending();
}
