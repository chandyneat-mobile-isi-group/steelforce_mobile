import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_sync_repository.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';

/// Pulls one depot's full record from the API into the local copy.
///
/// Best-effort: offline, or on any failure, the local copy is left as it was
/// and the caller reads it anyway.
class HydrateDepot extends UseCase<void, DepotIdParams> {
  const HydrateDepot(this._repository);
  final DepotSyncRepository _repository;

  @override
  ResultFuture<void> call(DepotIdParams params) =>
      _repository.hydrateDepot(params.depotId);
}
