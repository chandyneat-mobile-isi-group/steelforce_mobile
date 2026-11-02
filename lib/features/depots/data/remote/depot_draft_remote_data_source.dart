import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';

/// The registration routes of the backend: `POST /api/v1/mobile/depots` for
/// depots and non-depots, the record's file routes, and the pick lists.
///
/// Every method throws `ApiException` on a refusal or transport failure, and
/// `ServerException` on a 2xx whose body cannot be read.
abstract interface class DepotDraftRemoteDataSource {
  /// `POST /api/v1/mobile/depots`. [SavedDepotDraft.isNew] is false when the
  /// server recognised a resend of [draft]'s id (200 instead of 201).
  Future<SavedDepotDraft> createDraft(NewDepotDraft draft);

  /// `GET /api/v1/depots/references`.
  Future<DepotReferenceLists> fetchReferences();

  /// `GET /api/v1/profile-lists/{branch|factory}` — active values.
  Future<List<SupplierOption>> fetchSupplierOptions(DepotSupplierType type);

  /// `POST {depot-drafts|non-depots}/{id}/attachments`, multipart, by
  /// [kind]. [onProgress] receives bytes sent and total.
  Future<DepotDraftAttachment> uploadEvidence(
    String draftId,
    EvidenceUpload upload, {
    MobileDepotKind kind = MobileDepotKind.depot,
    void Function(int sent, int total)? onProgress,
  });

  /// `GET {depot-drafts|non-depots}/{id}/attachments` — fresh signed links.
  Future<DepotDraftAttachments> fetchAttachments(
    String draftId, {
    MobileDepotKind kind = MobileDepotKind.depot,
  });
}
