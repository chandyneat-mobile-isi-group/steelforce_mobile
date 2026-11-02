import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// Saves a new depot as a server-side draft. Retrying with the same
/// [NewDepotDraft] (same id) is safe and never creates a second draft.
class CreateDepotDraft extends UseCase<SavedDepotDraft, NewDepotDraft> {
  const CreateDepotDraft(this._repository);

  final DepotDraftRepository _repository;

  @override
  ResultFuture<SavedDepotDraft> call(NewDepotDraft params) =>
      _repository.createDraft(params);
}
