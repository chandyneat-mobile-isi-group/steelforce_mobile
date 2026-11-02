part of 'add_depot_bloc.dart';

/// Validate, submit and evidence upload for [AddDepotBloc].
///
/// Split out of the bloc file for size only; these are the same private
/// handlers, registered in the bloc's constructor.
extension _AddDepotSubmitHandlers on AddDepotBloc {
  // ---------------------------------------------------------------------
  // Validate
  // ---------------------------------------------------------------------

  /// A local completeness check only. `/api/v1/depot-drafts` has no dry run
  /// (the old business-partner route's `Commit: false` is gone with it), so
  /// what the server would refuse is learned on submit, field by field.
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
    emit(state.copyWith(sapPreCheckPassed: true));
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
          'blocked at ${blocked.step.number}/${BpFormStep.values.length} ${blocked.step.name}',
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

    // The id goes on the form and the form onto the device *before* the
    // send: a crash or a lost answer then resends under the same id, which the
    // server answers with the draft it already saved.
    DepotDraftSubmission.ensureId(state.draft);
    await _repository.saveDraft(state.draft);

    emit(state.copyWith(
      status: AddDepotStatus.submitting,
      progress: const DepotSubmitProgress(stage: SubmitStage.registering),
    ));

    final outcome = await _draftSubmission.submit(state.draft);

    switch (outcome) {
      case DepotDraftSaved(:final draft):
        _trace.ok('submit', draft.isNew ? 'draft created' : 'draft resent', {
          'draft': DebugTrace.id(draft.id),
          'status': draft.status,
        });

        // Photos go up only now, against the id the server returned.
        final photos =
            state.draft.attachments.where((a) => !a.isUploaded).length;
        if (photos > 0) {
          emit(state.copyWith(
            progress: DepotSubmitProgress(
              stage: SubmitStage.uploadingPhotos,
              photosTotal: photos,
            ),
          ));
        }
        final failed = await _draftSubmission.uploadEvidence(
          draft.id,
          state.draft.attachments,
          kind: draft.kind,
          onProgress: (completed, total) {
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
        _markUploaded(failed);
        (failed.isEmpty ? _trace.ok : _trace.warn)('photos', 'done', {
          'sent': photos - failed.length,
          'failed': failed.length,
        });

        emit(state.copyWith(
          status: AddDepotStatus.success,
          progress: state.progress.copyWith(stage: SubmitStage.finishing),
          depotNumber: '',
          awaitingApproval: true,
          queuedOffline: false,
          unsentDocuments: failed
              .map((a) => a.documentType)
              .whereType<DepotDocumentType>()
              .toList(),
        ));

        // A photo that failed keeps the form on the device, with its id and
        // the photos still to send: sending it again returns the same draft
        // and uploads only those. Otherwise the next "Add depot" opens blank.
        if (failed.isEmpty) {
          await _repository.clearDraft();
        } else {
          await _repository.saveDraft(state.draft);
        }

      case DepotDraftRefused(:final message, :final fieldErrors, :final step):
        _trace.fail('submit', 'refused', {
          'fields': DebugTrace.names(fieldErrors.keys),
        });
        emit(state.copyWith(
          status: AddDepotStatus.failure,
          errorMessage: message,
          errors: fieldErrors,
          currentStep: step ?? state.currentStep,
        ));

      case DepotDraftNotSent(:final message, :final offline):
        // No connection: the registration goes to the outbox, which sends it
        // when the server is reachable (or on "Sync now" in the Sync Center).
        if (offline && await _queueOffline()) {
          _trace.warn('submit', 'offline — queued for sync', const {});
          emit(state.copyWith(
            status: AddDepotStatus.success,
            progress: const DepotSubmitProgress(stage: SubmitStage.finishing),
            depotNumber: '',
            awaitingApproval: false,
            queuedOffline: true,
            unsentDocuments: const [],
          ));
          return;
        }
        // Already saved on the device above; nothing is lost and sending again
        // is safe.
        _trace.warn('submit', 'not sent — kept on device', const {});
        emit(state.copyWith(
          status: AddDepotStatus.failure,
          errorMessage: message,
        ));
    }
  }

  /// Moves the form and its unsent photographs into the outbox, then clears
  /// the wizard so the next "Add depot" opens blank. False when the outbox
  /// could not store it — the form then stays on the device as before.
  Future<bool> _queueOffline() async {
    final draft = state.draft;
    final name = draft.nameEn.trim().isNotEmpty ? draft.nameEn : draft.nameKh;
    final result = await _outbox.enqueueDraft(
      clientDraftId: draft.clientDraftId!,
      depotName: name.trim(),
      draftSnapshot: draft.toDraftJson(),
      photos: _pendingDocuments(),
    );
    final queued = result.when(success: (_) => true, failure: (_) => false);
    if (queued) await _repository.clearDraft();
    return queued;
  }

  /// Flags every photo that reached the server, so a resend skips it.
  void _markUploaded(List<BpAttachment> failed) {
    final attachments = state.draft.attachments;
    for (var i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      if (!a.isUploaded && !failed.contains(a)) {
        attachments[i] = a.copyWith(isUploaded: true);
      }
    }
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
