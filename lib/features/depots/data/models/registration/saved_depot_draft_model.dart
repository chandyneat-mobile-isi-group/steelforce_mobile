import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/registration/depot_draft_attachment_model.dart';
import 'package:steelforce/features/depots/data/models/registration/draft_json.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';

/// Reads `data` of a create/get answer (`DepotDraftView`) into the subset the
/// app acts on.
///
/// The id is the one hard requirement: without it no file can be attached and
/// the draft cannot be found again, so a body without one is a server fault.
abstract final class SavedDepotDraftModel {
  /// [kind] is what was sent; the answer's `listedAs` wins when present.
  static SavedDepotDraft fromJson(
    DataMap json, {
    bool isNew = true,
    MobileDepotKind kind = MobileDepotKind.depot,
  }) {
    final id =
        DraftJson.string(json['id']) ?? DraftJson.string(json['depotId']);
    if (id == null) {
      throw const ServerException(message: 'Depot draft answer has no id.');
    }
    return SavedDepotDraft(
      id: id,
      // A new draft is version 1; a body without one is read as that.
      version: DraftJson.integer(json['version']) ?? 1,
      status: DraftJson.string(json['status']) ?? '',
      nameEn: DraftJson.string(json['nameEn']) ?? '',
      kind: MobileDepotKind.fromApi(json['listedAs']) ?? kind,
      isNew: isNew,
      canEdit: DraftJson.boolean(json['canEdit']),
      createdAt: DraftJson.instant(json['createdAt']),
      attachments: DepotDraftAttachmentModel.listFromJson(json),
    );
  }
}
