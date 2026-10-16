import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

/// One captured file waiting to be uploaded.
///
/// Deliberately a path and a timestamp rather than bytes: the file stays on
/// disk until the upload is confirmed, and `capturedAt` is stamped at photo
/// time so a queued upload is dated to the visit, not to whenever the
/// connection came back.
class PendingDepotDocument {
  const PendingDepotDocument({
    required this.type,
    required this.filePath,
    required this.capturedAt,
  });

  final DepotDocumentType type;
  final String filePath;
  final DateTime capturedAt;
}

/// What happened to a batch of uploads.
///
/// [rejected] is kept apart from [failed] because the two demand opposite
/// responses: a 4xx will fail identically forever — a PDF sent to a photo slot,
/// a file over 10 MB — so retrying it wastes a rep's connection, while a 5xx or
/// a dropped link is worth another attempt.
class DepotDocumentUploadOutcome {
  const DepotDocumentUploadOutcome({
    this.uploaded = const [],
    this.failed = const [],
    this.rejected = const [],
  });

  final List<DepotDocumentType> uploaded;
  final List<DepotDocumentType> failed;
  final List<DepotDocumentType> rejected;

  bool get isCompleteSuccess => failed.isEmpty && rejected.isEmpty;

  /// Slots the rep still needs to deal with, in a stable order so the message
  /// reads the same every time.
  List<DepotDocumentType> get outstanding =>
      [...failed, ...rejected]..sort((a, b) => a.index.compareTo(b.index));
}

/// The depot's on-site evidence photographs.
///
/// Separate from the registration repository because the lifetime differs: the
/// documents outlive the draft and are edited from the depot's detail screen
/// long after registration closed.
abstract interface class DepotDocumentRepository {
  /// What the server holds for [depotId], and what is still missing.
  ResultFuture<DepotDocumentsState> fetch(String depotId);

  /// Uploads every captured file, one request each.
  ///
  /// **Never throws and never reports overall failure**, because a depot is
  /// not allowed to be lost to a photograph. The registration has already
  /// succeeded by the time this runs; HQ blocks approval on the server's own
  /// `isComplete` rather than the app refusing to save
  /// (`docs/feature/depot/mobile/depot-documents.md` §The checklist).
  /// [onProgress] is called after each file settles, with the number
  /// completed so far. Reported per file because there is no batch endpoint —
  /// each upload is its own request, and a rep on a market connection should
  /// see the count move rather than watch one long spinner.
  ResultFuture<DepotDocumentUploadOutcome> uploadAll({
    required String depotId,
    required List<PendingDepotDocument> documents,
    void Function(int completed, int total)? onProgress,
  });

  ResultFuture<void> delete({
    required String depotId,
    required String documentId,
  });
}
