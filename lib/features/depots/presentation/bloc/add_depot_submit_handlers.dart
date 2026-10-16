part of 'add_depot_bloc.dart';

/// Validate, submit and evidence upload for [AddDepotBloc].
///
/// Split out of the bloc file for size only; these are the same private
/// handlers, registered in the bloc's constructor.
extension _AddDepotSubmitHandlers on AddDepotBloc {
  // ---------------------------------------------------------------------
  // Validate
  // ---------------------------------------------------------------------

  Future<void> _onValidateWithSap(
      ValidateWithSap event, Emitter<AddDepotState> emit) async {
    final blocked = _firstIncompleteStep();
    if (blocked != null) {
      emit(state.copyWith(
        currentStep: blocked.step,
        errors: blocked.errors,
      ));
      return;
    }

    final rep = await _resolveRep();
    if (rep == null) {
      emit(state.copyWith(errorMessage: _repIdentityUnavailable));
      return;
    }

    emit(state.copyWith(status: AddDepotStatus.validating));
    _trace.send('precheck', 'requested');

    final outcome = await _submission.validate(
      state.draft,
      rep: rep,
      priceGroupResolver: state.references.priceGroupFor,
    );

    switch (outcome) {
      case BpSubmissionCreated():
        _trace.ok('precheck', 'SAP would accept');
        emit(state.copyWith(
          status: AddDepotStatus.editing,
          sapPreCheckPassed: true,
        ));
      case BpSubmissionRejected(:final message, :final step):
        _trace.fail('precheck', 'SAP would reject', const {});
        emit(state.copyWith(
          status: AddDepotStatus.editing,
          errorMessage: message,
          currentStep: step ?? state.currentStep,
        ));
      case BpSubmissionUnreachable(:final message):
        // Not a failure of the form. The rep can still submit, which will
        // queue if the connection is still down.
        _trace.warn('precheck', 'unreachable', const {});
        emit(state.copyWith(
          status: AddDepotStatus.editing,
          errorMessage: message,
        ));
    }
  }

  // ---------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------

  Future<void> _onSubmit(SubmitToHQ event, Emitter<AddDepotState> emit) async {
    _trace.send('submit', 'requested');

    // Validate EVERY step, not just the visible one. On tablet all steps show
    // at once, and on phone the rep can jump back via GoToStep and break an
    // earlier step after it was already passed.
    final blocked = _firstIncompleteStep();
    if (blocked != null) {
      _trace.fail(
          'submit',
          'blocked at ${blocked.step.number}/5 ${blocked.step.name}',
          {'missing': DebugTrace.names(blocked.errors.keys)});
      emit(state.copyWith(
        currentStep: blocked.step,
        errors: blocked.errors,
      ));
      return;
    }

    // A draft saved by an older build may already have been created on the
    // server (that build registered early, before review). There is no
    // contract endpoint to amend a business-partner registration, and
    // re-posting would create a duplicate partner, so only the photographs
    // still on the device are sent.
    if (state.draft.isDepotCreatedOnServer) {
      await _finishLegacyServerDraft(emit);
      return;
    }

    // The personnel number must be the signed-in rep's. Refused before any
    // network call, and the form is kept, so the rep can sign in and resend.
    final rep = await _resolveRep();
    if (rep == null) {
      await _repository.saveDraft(state.draft);
      emit(state.copyWith(
        status: AddDepotStatus.failure,
        errorMessage: _repIdentityUnavailable,
      ));
      return;
    }

    emit(state.copyWith(
      status: AddDepotStatus.submitting,
      progress: const DepotSubmitProgress(stage: SubmitStage.registering),
    ));

    // Built from the draft as it is *now*, so every edit made up to the
    // confirm tap is what the backend receives.
    final outcome = await _submission.submit(
      state.draft,
      rep: rep,
      priceGroupResolver: state.references.priceGroupFor,
    );

    switch (outcome) {
      case BpSubmissionCreated(
          :final depotNumber,
          :final documentId,
          :final isPendingApproval,
        ):
        _trace.ok('submit', isPendingApproval ? 'awaiting HQ' : 'accepted', {
          'depot': DebugTrace.id(depotNumber),
          'record': DebugTrace.id(documentId),
        });

        // Evidence goes up only now: the documents endpoint is addressed by
        // depot id, which did not exist until this moment.
        //
        // Addressed by `documentId`, not the SAP number. A record awaiting HQ
        // approval has no SAP number, and passing the empty string here made
        // `_uploadEvidence` treat every pending registration as having no
        // depot to attach to — so the photographs were held on the device
        // for a record that could perfectly well accept them.
        final photos = state.draft.attachments.length;
        if (photos > 0) {
          emit(state.copyWith(
            progress: DepotSubmitProgress(
              stage: SubmitStage.uploadingPhotos,
              photosTotal: photos,
            ),
          ));
        }

        final unsent = await _uploadEvidence(
          documentId,
          false,
          onPhotoProgress: (completed, total) {
            // `emit` after an await is safe while the handler is still running,
            // and this one only ever runs inside it.
            if (isClosed) return;
            emit(state.copyWith(
              progress: state.progress.copyWith(
                stage: SubmitStage.uploadingPhotos,
                photosSent: completed,
                photosTotal: total,
              ),
            ));
          },
        );

        emit(state.copyWith(
          status: AddDepotStatus.success,
          progress: state.progress.copyWith(stage: SubmitStage.finishing),
          depotNumber: depotNumber,
          awaitingApproval: isPendingApproval,
          queuedOffline: false,
          unsentDocuments: unsent,
        ));

        // Cleared last, and only on a confirmed create. Clearing before the
        // uploads would lose the local paths of any photograph that failed.
        await _repository.clearDraft();

      case BpSubmissionRejected(:final message, :final step):
        _trace.fail('submit', 'rejected', const {});
        emit(state.copyWith(
          status: AddDepotStatus.failure,
          errorMessage: message,
          currentStep: step ?? state.currentStep,
        ));

      case BpSubmissionUnreachable(
          :final message,
          :final request,
          :final mayHaveLanded
        ):
        // Saved locally first (ADR-002): the exact payload and its photographs
        // go into the outbox, and the sync engine replays it when SAP is
        // reachable. A request that may already have landed is stored for the
        // rep to check instead — see [DepotRegistrationOutbox].
        if (await _enqueue(request, mayHaveLanded: mayHaveLanded)) {
          await _repository.clearDraft();
          _trace.ok(
            'submit',
            mayHaveLanded ? 'held for review' : 'queued',
            const {},
          );
          emit(
            state.copyWith(
              status: AddDepotStatus.success,
              queuedOffline: true,
              queuedNeedsReview: mayHaveLanded,
            ),
          );
          return;
        }

        // No outbox, or it could not be written: keep the form as a resumable
        // draft rather than lose the rep's work.
        await _repository.saveDraft(state.draft);
        _trace.warn('submit', mayHaveLanded ? 'unknown' : 'held', const {});
        emit(state.copyWith(
          status: AddDepotStatus.failure,
          queuedOffline: true,
          errorMessage: message,
        ));
    }
  }

  /// Writes the registration to the outbox. False when there is no outbox or
  /// the local write failed, so the caller can fall back to the draft.
  Future<bool> _enqueue(
    BusinessPartnerRequest request, {
    required bool mayHaveLanded,
  }) async {
    final outbox = _outbox;
    if (outbox == null) return false;
    final draft = state.draft;
    final result = await outbox.enqueue(
      request: request,
      depotName: draft.nameEn.trim().isNotEmpty ? draft.nameEn : draft.nameKh,
      photos: _pendingDocuments(),
      mayHaveLanded: mayHaveLanded,
      draftSnapshot: draft,
    );
    return result.when(success: (_) => true, failure: (_) => false);
  }

  /// The captured photographs not yet on the server, as upload requests.
  ///
  /// A kind with no matching slot is skipped rather than guessed — sending it
  /// to the wrong slot would be worse than not sending it, because the rep
  /// would see it as filed.
  List<PendingDepotDocument> _pendingDocuments() {
    final pending = <PendingDepotDocument>[];
    for (final attachment in state.draft.attachments) {
      if (attachment.isUploaded) continue;
      final type = attachment.documentType;
      if (type == null) {
        _trace.warn('photos', 'unknown slot', {'kind': attachment.kind});
        continue;
      }
      pending.add(
        PendingDepotDocument(
          type: type,
          filePath: attachment.localPath,
          capturedAt: attachment.capturedAt,
        ),
      );
    }
    return pending;
  }

  Future<void> _finishLegacyServerDraft(Emitter<AddDepotState> emit) async {
    _trace.warn('submit', 'draft already on server; sending photos only');
    final depotId = state.draft.serverDepotId!;
    emit(state.copyWith(
      status: AddDepotStatus.submitting,
      progress: const DepotSubmitProgress(stage: SubmitStage.uploadingPhotos),
    ));
    final unsent = await _uploadEvidence(depotId, false);
    emit(state.copyWith(
      status: AddDepotStatus.success,
      progress: const DepotSubmitProgress(stage: SubmitStage.finishing),
      depotNumber: state.draft.depotNumber.isNotEmpty
          ? state.draft.depotNumber
          : state.draft.serverDepotId,
      awaitingApproval: state.draft.isPendingHqApproval,
      queuedOffline: false,
      unsentDocuments: unsent,
    ));
    await _repository.clearDraft();
  }

  /// The first step that does not validate, or null when the form is complete.
  _BlockedStep? _firstIncompleteStep() {
    for (final step in BpFormStep.values) {
      final errors = state.draft.validateStep(step);
      if (errors.isNotEmpty) return _BlockedStep(step, errors);
    }
    return null;
  }

  /// Uploads the captured photographs against the newly created depot.
  ///
  /// Returns the slots that did not make it. **Never throws**: the depot has
  /// already been created, and letting a photograph fail the registration would
  /// lose a shop the rep is standing in for a reason unrelated to it. The
  /// server blocks HQ approval on its own `isComplete` instead
  /// (`docs/feature/depot/mobile/depot-documents.md` §The checklist).
  Future<List<DepotDocumentType>> _uploadEvidence(
    String depotId,
    bool queuedOffline, {
    void Function(int completed, int total)? onPhotoProgress,
  }) async {
    // Already on the server (a legacy draft) means already filed — resending
    // would duplicate the document.
    final attachments =
        state.draft.attachments.where((a) => !a.isUploaded).toList();
    if (attachments.isEmpty) return const [];

    // A queued registration has no server-side depot to attach to yet, and
    // no id worth uploading against. The photographs stay on the device.
    if (queuedOffline || depotId.isEmpty) {
      _trace.warn('photos', 'deferred — no server depot id yet',
          {'held': attachments.length});
      return attachments
          .map((a) => a.documentType)
          .whereType<DepotDocumentType>()
          .toList();
    }

    final pending = _pendingDocuments();
    if (pending.isEmpty) return const [];

    final result = await _documents.uploadAll(
      depotId: depotId,
      documents: pending,
      onProgress: onPhotoProgress,
    );

    return result.when(
      success: (outcome) {
        final clean = outcome.isCompleteSuccess;
        (clean ? _trace.ok : _trace.warn)(
            'photos', clean ? 'all sent' : 'partial', {
          'sent': outcome.uploaded.length,
          'retry': outcome.failed.length,
          'rejected': outcome.rejected.length,
        });
        return outcome.outstanding;
      },
      // uploadAll is contracted never to report overall failure; this branch
      // exists so a future change to that contract cannot silently drop the
      // slots on the floor.
      failure: (_) => pending.map((p) => p.type).toList(),
    );
  }
}
