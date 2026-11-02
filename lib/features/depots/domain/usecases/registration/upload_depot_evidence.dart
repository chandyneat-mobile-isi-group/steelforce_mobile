import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// Adds one evidence file to a draft the server has already saved. Never
/// called before the draft exists — the server owns the draft id it hangs on.
class UploadDepotEvidence
    extends UseCase<DepotDraftAttachment, UploadDepotEvidenceParams> {
  const UploadDepotEvidence(this._repository);

  final DepotDraftRepository _repository;

  @override
  ResultFuture<DepotDraftAttachment> call(UploadDepotEvidenceParams params) =>
      _repository.uploadEvidence(
        params.draftId,
        params.upload,
        kind: params.kind,
        onProgress: params.onProgress,
      );
}

class UploadDepotEvidenceParams extends Equatable {
  const UploadDepotEvidenceParams({
    required this.draftId,
    required this.upload,
    this.kind = MobileDepotKind.depot,
    this.onProgress,
  });

  /// The id the server returned for the saved draft.
  final String draftId;
  final EvidenceUpload upload;

  /// Which route the record lives on.
  final MobileDepotKind kind;

  /// Bytes sent and total, for a per-file progress bar.
  final void Function(int sent, int total)? onProgress;

  @override
  List<Object?> get props => [draftId, upload, kind];
}
