import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_to_depot_draft.dart';
import 'package:steelforce/features/depots/data/mappers/depot_evidence_upload.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';
import 'package:steelforce/features/depots/domain/usecases/registration/create_depot_draft.dart';
import 'package:steelforce/features/depots/domain/usecases/registration/upload_depot_evidence.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_draft_field_errors.dart';

/// What came of sending the form. Sealed so the bloc handles every case.
sealed class DepotDraftOutcome {
  const DepotDraftOutcome();
}

/// The server holds the draft — new (201) or recognised as a resend (200).
class DepotDraftSaved extends DepotDraftOutcome {
  const DepotDraftSaved(this.draft);
  final SavedDepotDraft draft;
}

/// The server refused it; the rep must change something. [fieldErrors] are
/// keyed by the form's own field names, [step] is where the first one lives.
class DepotDraftRefused extends DepotDraftOutcome {
  const DepotDraftRefused({
    required this.message,
    this.fieldErrors = const {},
    this.step,
  });
  final String message;
  final Map<String, String> fieldErrors;
  final BpFormStep? step;
}

/// Not saved as far as the app knows: offline, a timeout, or a server fault.
/// Sending again is safe — the form's id makes a resend return the saved
/// draft instead of a second one.
class DepotDraftNotSent extends DepotDraftOutcome {
  const DepotDraftNotSent(this.message, {this.offline = false});
  final String message;

  /// The request never left the handset (no connection, or the server could
  /// not be reached). The wizard queues it for the outbox instead of failing.
  final bool offline;
}

/// Sends the wizard's form to `POST /api/v1/mobile/depots` — a depot or a
/// non-depot, as step 1 picked — then its photos to the record the server
/// returned.
class DepotDraftSubmission {
  const DepotDraftSubmission({
    required CreateDepotDraft createDraft,
    required UploadDepotEvidence uploadEvidence,
  })  : _create = createDraft,
        _upload = uploadEvidence;

  final CreateDepotDraft _create;
  final UploadDepotEvidence _upload;

  /// Gives [draft] its id if it has none. The caller saves the form after
  /// this and **before** [submit], so a crash mid-send still resends under
  /// the same id.
  static void ensureId(BpDepotDraft draft) => draft.clientDraftId ??= Uuid.v4();

  Future<DepotDraftOutcome> submit(BpDepotDraft draft) async {
    final id = draft.clientDraftId ?? (throw StateError('ensureId first'));
    final result = await _create(draft.toNewDepotDraft(id: id));
    return result.when(
      success: (saved) => DepotDraftSaved(saved),
      failure: (failure) => _classify(failure, draft),
    );
  }

  DepotDraftOutcome _classify(Failure failure, BpDepotDraft draft) {
    if (failure is DepotDraftRejectedFailure) {
      final (fields, step) = DepotDraftFieldErrors.map(
        failure.fieldErrors,
        telephoneIsMobile: draft.telephoneSameAsMobile,
      );
      return DepotDraftRefused(
        message: failure.userMessage,
        fieldErrors: fields,
        step: step,
      );
    }
    return DepotDraftNotSent(
      failure.userMessage,
      offline: failure is NetworkFailure || failure is ServerUnreachableFailure,
    );
  }

  /// Uploads the photos not yet on the server, one at a time, and returns the
  /// ones that did not make it. **Never throws**: the draft already exists,
  /// and a failed photo must not undo it.
  Future<List<BpAttachment>> uploadEvidence(
    String draftId,
    List<BpAttachment> attachments, {
    MobileDepotKind kind = MobileDepotKind.depot,
    void Function(int completed, int total)? onProgress,
  }) async {
    final pending = attachments.where((a) => !a.isUploaded).toList();
    final failed = <BpAttachment>[];
    for (var i = 0; i < pending.length; i++) {
      final attachment = pending[i];
      final result = await _upload(UploadDepotEvidenceParams(
        draftId: draftId,
        kind: kind,
        upload: _uploadFor(attachment),
      ));
      if (result.when(success: (_) => false, failure: (_) => true)) {
        failed.add(attachment);
      }
      onProgress?.call(i + 1, pending.length);
    }
    return failed;
  }

  static EvidenceUpload _uploadFor(BpAttachment a) => DepotEvidenceUpload.of(a);

  /// See [DepotEvidenceUpload.categoryFor].
  static (EvidenceCategory, String?) evidenceFor(String kind) =>
      DepotEvidenceUpload.categoryFor(kind);
}
