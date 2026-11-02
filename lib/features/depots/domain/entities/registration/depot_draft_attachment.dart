import 'package:equatable/equatable.dart';

/// What an evidence file shows. The backend's `EvidenceCategory`; `other` is
/// its default when none is sent.
enum EvidenceCategory {
  businessLicense('BusinessLicense'),
  patentTax('PatentTax'),
  ownerId('OwnerId'),
  shopPhoto('ShopPhoto'),
  contract('Contract'),
  other('Other');

  const EvidenceCategory(this.apiValue);

  final String apiValue;

  static EvidenceCategory? fromApi(Object? value) {
    for (final category in values) {
      if (category.apiValue == '$value') return category;
    }
    return null;
  }
}

enum DepotAttachmentKind { cover, evidence }

/// A stored cover photo or evidence file, as the server returned it.
///
/// [url] and [thumbnailUrl] are signed links that work **without** a token
/// until [urlExpiresAt]. They are used as given, never rebuilt, never sent
/// with the bearer token, and never persisted past their expiry — fetch the
/// attachments again for fresh ones.
class DepotDraftAttachment extends Equatable {
  const DepotDraftAttachment({
    required this.id,
    required this.kind,
    required this.originalFileName,
    required this.contentType,
    required this.fileSize,
    required this.url,
    required this.urlExpiresAt,
    this.category,
    this.note,
    this.thumbnailUrl,
    this.takenAt,
    this.canRemove = false,
  });

  final String id;
  final DepotAttachmentKind kind;
  final EvidenceCategory? category;
  final String? note;
  final String originalFileName;
  final String contentType;
  final int fileSize;
  final String url;

  /// Photos only.
  final String? thumbnailUrl;
  final DateTime urlExpiresAt;
  final DateTime? takenAt;
  final bool canRemove;

  bool get isImage => contentType.startsWith('image/');

  /// True once the links stop working, with [margin] to spare so a link is
  /// not handed to a viewer seconds before it dies.
  bool linksExpired(DateTime now,
          {Duration margin = const Duration(minutes: 1)}) =>
      !now.add(margin).isBefore(urlExpiresAt);

  @override
  List<Object?> get props => [
        id,
        kind,
        category,
        note,
        originalFileName,
        contentType,
        fileSize,
        url,
        thumbnailUrl,
        urlExpiresAt,
        takenAt,
        canRemove,
      ];
}

/// A draft's files: the cover (null when none) and the evidence, oldest first.
class DepotDraftAttachments extends Equatable {
  const DepotDraftAttachments({this.cover, this.evidence = const []});

  final DepotDraftAttachment? cover;
  final List<DepotDraftAttachment> evidence;

  bool get isEmpty => cover == null && evidence.isEmpty;

  @override
  List<Object?> get props => [cover, evidence];
}

/// One file the rep chose, to send as evidence once the draft exists.
class EvidenceUpload extends Equatable {
  const EvidenceUpload({
    required this.id,
    required this.filePath,
    required this.fileName,
    this.category,
    this.note,
    this.takenAt,
    this.latitude,
    this.longitude,
  });

  /// Client-generated v4 UUID, reused on retry: a resend of the same id and
  /// file answers 200 with the stored file rather than a duplicate.
  final String id;

  /// Local path of the chosen file. Read for the upload only — never sent.
  final String filePath;
  final String fileName;
  final EvidenceCategory? category;

  /// ≤ 200 characters.
  final String? note;

  /// When the photo was taken. Sent as a form field because the server strips
  /// the file's own metadata.
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props =>
      [id, filePath, fileName, category, note, takenAt, latitude, longitude];
}
