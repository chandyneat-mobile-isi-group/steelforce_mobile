import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// The six SAP lists a sales area is filled from. [call] with `true` to fetch
/// again instead of reusing this session's copy.
class LoadDepotReferences extends UseCase<DepotReferenceLists, bool> {
  const LoadDepotReferences(this._repository);

  final DepotDraftRepository _repository;

  @override
  ResultFuture<DepotReferenceLists> call(bool params) =>
      _repository.loadReferences(refresh: params);
}
