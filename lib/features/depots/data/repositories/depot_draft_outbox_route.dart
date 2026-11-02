import 'dart:convert';

import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_to_depot_draft.dart';
import 'package:steelforce/features/depots/data/mappers/depot_evidence_upload.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

/// How the outbox replays a wizard registration queued while offline:
/// `POST /api/v1/mobile/depots`, then each photograph to the saved record.
///
/// Unlike the retired business-partner route, this one is idempotent — the
/// form's client draft id makes a resend return the record already saved. So
/// a lost answer is simply sent again; no row has to wait for the rep to check
/// the depot list first.
///
/// Such a row is marked by its `payload` ([payloadFor]) and carries the form
/// itself in `draftJson`, which is what is sent.
class DepotDraftOutboxRoute {
  const DepotDraftOutboxRoute(this._drafts);

  final DepotDraftRepository _drafts;

  static const String format = 'mobileDepotDraft';

  /// The `payload` column for a row this route sends.
  static String payloadFor(String clientDraftId) =>
      jsonEncode({'format': format, 'id': clientDraftId});

  /// Whether a stored `payload` belongs to this route rather than the legacy
  /// business-partner one.
  static bool owns(String payload) {
    try {
      final json = jsonDecode(payload);
      return json is Map && json['format'] == format;
    } catch (_) {
      return false;
    }
  }

  /// The form stored on a row, or null when it is missing, unreadable, or has
  /// lost the id that makes a resend safe.
  static BpDepotDraft? formOf(String? draftJson) {
    if (draftJson == null) return null;
    try {
      final form = BpDepotDraft.fromDraftJson(
        Map<String, dynamic>.from(jsonDecode(draftJson) as Map),
      );
      final id = form.clientDraftId;
      return id == null || id.isEmpty ? null : form;
    } catch (_) {
      return null;
    }
  }

  ResultFuture<SavedDepotDraft> send(BpDepotDraft form) =>
      _drafts.createDraft(form.toNewDepotDraft(id: form.clientDraftId!));

  /// Whether a failed send is retried by the drain with a backoff, rather
  /// than handed to the rep. A 429 is the server asking for exactly that.
  static bool isBusy(Failure failure) =>
      failure is ServerFailure ||
      (failure is DepotDraftRejectedFailure && failure.statusCode == 429);

  /// Uploads [photos] to the saved record [draftId], one at a time. Never
  /// throws. A refusal of the file itself (wrong type, too large) is
  /// `rejected` — it would fail identically forever; anything else is
  /// `failed`, for the next round.
  Future<DepotDocumentUploadOutcome> upload(
    String draftId,
    BpDepotDraft form,
    List<PendingDepotDocument> photos,
  ) async {
    final kind = form.toNewDepotDraft(id: draftId).kind;
    final slots = {
      for (final e in BpAttachment.kindToDocumentType.entries) e.value: e.key,
    };
    final uploaded = <DepotDocumentType>[];
    final failed = <DepotDocumentType>[];
    final rejected = <DepotDocumentType>[];
    for (final photo in photos) {
      final slot = slots[photo.type] ?? photo.type.name;
      final upload = DepotEvidenceUpload.of(BpAttachment(
        kind: slot,
        localPath: photo.filePath,
        capturedAt: photo.capturedAt,
      ));
      final result = await _drafts.uploadEvidence(draftId, upload, kind: kind);
      result.when(
        success: (_) => uploaded.add(photo.type),
        failure: (f) =>
            (f is DepotDraftRejectedFailure && !isBusy(f) ? rejected : failed)
                .add(photo.type),
      );
    }
    return DepotDocumentUploadOutcome(
      uploaded: uploaded,
      failed: failed,
      rejected: rejected,
    );
  }
}
