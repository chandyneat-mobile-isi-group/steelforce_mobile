import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/registration/draft_json.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';

/// Reads `DepotDraftAttachmentView` and `DepotDraftAttachmentsView`.
///
/// An item without an id, a link or an expiry is dropped: a file the app can
/// neither open nor refresh is worse than one it does not show.
abstract final class DepotDraftAttachmentModel {
  static DepotDraftAttachment? fromJson(DataMap json) {
    final id = DraftJson.string(json['id']);
    final url = DraftJson.string(json['url']);
    final expires = DraftJson.instant(json['urlExpiresAt']);
    if (id == null || url == null || expires == null) return null;
    return DepotDraftAttachment(
      id: id,
      kind: _kind(json['kind']),
      category: EvidenceCategory.fromApi(json['category']),
      note: DraftJson.string(json['note']),
      originalFileName: DraftJson.string(json['originalFileName']) ?? '',
      contentType: DraftJson.string(json['contentType']) ?? '',
      fileSize: DraftJson.integer(json['fileSize']) ?? 0,
      url: url,
      thumbnailUrl: DraftJson.string(json['thumbnailUrl']),
      urlExpiresAt: expires,
      takenAt: DraftJson.instant(json['takenAt']),
      canRemove: DraftJson.boolean(json['canRemove']),
    );
  }

  /// `{cover, evidence}` — also the shape embedded in a draft view.
  static DepotDraftAttachments listFromJson(DataMap json) {
    final cover = DraftJson.map(json['cover']);
    return DepotDraftAttachments(
      cover: cover == null ? null : fromJson(cover),
      evidence: [
        for (final item in DraftJson.maps(json['evidence']))
          if (fromJson(item) case final attachment?) attachment,
      ],
    );
  }

  static DepotAttachmentKind _kind(Object? value) => switch ('$value') {
        'Cover' || '1' => DepotAttachmentKind.cover,
        _ => DepotAttachmentKind.evidence,
      };
}
