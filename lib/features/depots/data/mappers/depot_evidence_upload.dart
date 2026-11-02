import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';

/// A wizard photograph as one evidence upload for the saved draft.
///
/// Shared by the wizard's own send and the offline outbox's replay, so a
/// photograph is filed under the same category whichever path sends it.
abstract final class DepotEvidenceUpload {
  static EvidenceUpload of(BpAttachment a) {
    final (category, note) = categoryFor(a.kind);
    final path = a.localPath;
    return EvidenceUpload(
      id: Uuid.v4(),
      filePath: path,
      fileName: path.split(RegExp(r'[/\\]')).last,
      category: category,
      note: note,
      takenAt: a.capturedAt,
    );
  }

  /// The form's photo slots as the server's evidence categories. A slot with
  /// no matching category goes as `Other` with the slot named in the note.
  static (EvidenceCategory, String?) categoryFor(String kind) => switch (kind) {
        'outlet_front' => (EvidenceCategory.shopPhoto, 'Storefront'),
        'outlet_inside' => (EvidenceCategory.shopPhoto, 'Inside the shop'),
        'id_card' => (EvidenceCategory.ownerId, null),
        'patent_tax' => (EvidenceCategory.patentTax, null),
        'vat_cert' => (EvidenceCategory.other, 'VAT certificate'),
        _ => (EvidenceCategory.other, kind),
      };
}
