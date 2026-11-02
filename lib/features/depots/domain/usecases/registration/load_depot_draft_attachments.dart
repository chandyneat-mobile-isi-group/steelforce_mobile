import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// A saved draft's cover and evidence, with fresh signed links. Call again
/// when a link's `urlExpiresAt` has passed — never rebuild a link by hand.
class LoadDepotDraftAttachments extends UseCase<DepotDraftAttachments, String> {
  const LoadDepotDraftAttachments(this._repository);

  final DepotDraftRepository _repository;

  /// [params] is the draft id.
  @override
  ResultFuture<DepotDraftAttachments> call(String params) =>
      _repository.loadAttachments(params);
}
