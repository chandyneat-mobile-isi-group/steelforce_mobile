import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';

/// Registering a new depot or non-depot on the server, and the lists it is
/// filled from. Online only: the draft is the server's record.
abstract interface class DepotDraftRepository {
  /// Saves [draft]. Safe to call again with the same draft after a lost
  /// answer — its client id makes the server return the saved draft.
  ResultFuture<SavedDepotDraft> createDraft(NewDepotDraft draft);

  /// The six sales-area lists. Loaded once and reused for the session; pass
  /// [refresh] to fetch again (a retry, or lists that were empty).
  ResultFuture<DepotReferenceLists> loadReferences({bool refresh = false});

  /// Active Branch or Factory values to rank as suppliers.
  ResultFuture<List<SupplierOption>> loadSupplierOptions(
      DepotSupplierType type);

  /// Adds one evidence file to the saved record [draftId], on the route its
  /// [kind] lives on. Resending the same
  /// [EvidenceUpload] (same id, same file) never stores it twice.
  ResultFuture<DepotDraftAttachment> uploadEvidence(
    String draftId,
    EvidenceUpload upload, {
    MobileDepotKind kind = MobileDepotKind.depot,
    void Function(int sent, int total)? onProgress,
  });

  /// The cover and evidence of [draftId], with fresh links.
  ResultFuture<DepotDraftAttachments> loadAttachments(String draftId);
}
