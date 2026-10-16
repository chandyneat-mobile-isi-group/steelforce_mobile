// =============================================================================
// add_depot_bloc.dart
//
// The whole form is ONE object (BpDepotDraft) instead of an event per
// field, so adding a SAP field never touches this file.
//
// Rewritten for the single-write endpoint. The three-call server-draft
// protocol is gone: there is no `serverDraftId`, no per-step PATCH, and no
// network call before submit. The consequences are worth stating because they
// are the point of the change:
//
//   * The form opens offline. It used to need `POST /draft` to return an id
//     before the rep could type, which failed exactly where reps work.
//   * `Next` is instant. It used to flush a patch and await the response.
//   * A resumed form comes from the device, not the server — see
//     BusinessPartnerRepository.loadDraft.
// =============================================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/features/depots/data/local/rep_sales_context_source.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/bp_form_step.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/entities/depot_submit_progress.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';
import 'package:steelforce/features/depots/presentation/bloc/business_partner_submission.dart';
import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';

part 'add_depot_event.dart';
part 'add_depot_state.dart';
part 'add_depot_submit_handlers.dart';

// -----------------------------------------------------------------------------
// Bloc
// -----------------------------------------------------------------------------
/// Console tracer for the registration flow. Debug builds only; see
/// [DebugTrace] for what may and may not be traced.
const _trace = DebugTrace('registration');

class AddDepotBloc extends Bloc<AddDepotEvent, AddDepotState> {
  final BusinessPartnerRepository _repository;
  final DepotDocumentRepository _documents;
  final BusinessPartnerSubmission _submission;
  final RepSalesContextSource _repSource;

  /// Holds a registration SAP could not be reached for and replays it when it
  /// can. Optional so tests that never go offline need not supply one; without
  /// it an unreachable submit falls back to keeping the form as a draft.
  final DepotRegistrationOutbox? _outbox;

  /// The signed-in rep, once resolved. Null until [OpenForm] has read it, and
  /// null for good when there is no trustworthy identity — in which case the
  /// form still opens and saves locally, but will not send.
  RepSalesContext? _rep;

  AddDepotBloc({
    required BusinessPartnerRepository repository,
    required DepotDocumentRepository documents,
    required BusinessPartnerSubmission submission,
    required RepSalesContextSource repSource,
    DepotRegistrationOutbox? outbox,
    BpDepotDraft? initialDraft,
  })  : _repository = repository,
        _documents = documents,
        _submission = submission,
        _repSource = repSource,
        _outbox = outbox,
        super(AddDepotState(
          currentStep: BpFormStep.identity,
          draft: (initialDraft ?? BpDepotDraft())..applyRepDefaults(_noRep),
        )) {
    _trace.begin('depot registration');
    _trace.step('form', 'opened', {'step': '1/5 identity'});
    on<OpenForm>(_onOpenForm);
    on<DraftChanged>(_onDraftChanged);
    on<NextStep>(_onNextStep);
    on<PreviousStep>(_onPreviousStep);
    on<GoToStep>(_onGoToStep);
    on<AttachmentAdded>(_onAttachmentAdded);
    on<RetryUploadAttachment>(_onRetryUploadAttachment);
    on<AttachmentRemoved>(_onAttachmentRemoved);
    on<ValidateWithSap>(_onValidateWithSap);
    on<SubmitToHQ>(_onSubmit);
    on<DiscardDraft>(_onDiscardDraft);
  }

  /// The rep's own sales area, exposed so the review screen can show what will
  /// be sent when they have not overridden it.
  ///
  /// Before (or without) a resolved identity this is an empty context, which
  /// makes the draft fall back to the documented sales-area defaults and
  /// carries no personnel number — never somebody else's.
  RepSalesContext get rep => _rep ?? _noRep;

  /// True once the signed-in rep's personnel number is known.
  bool get hasRepIdentity => _rep != null;

  /// Builds the exact payload for the current form. Used by the review step.
  BusinessPartnerRequest previewRequest() => _submission.buildRequest(
        state.draft,
        rep: rep,
        priceGroupResolver: state.references.priceGroupFor,
      );

  /// Resolves the rep if not already known. Re-tried on every send because a
  /// session restored after the form opened must not leave it unsendable.
  Future<RepSalesContext?> _resolveRep() async {
    if (_rep != null) return _rep;
    try {
      _rep = await _repSource.current();
    } on Object {
      _rep = null;
    }
    if (_rep == null) _trace.warn('rep', 'no signed-in identity');
    return _rep;
  }

  // ---------------------------------------------------------------------
  // Open
  // ---------------------------------------------------------------------

  Future<void> _onOpenForm(OpenForm event, Emitter<AddDepotState> emit) async {
    emit(state.copyWith(status: AddDepotStatus.opening));

    // Neither call throws by contract, so there is no try/catch and no path
    // where the form fails to open. That is the behavioural difference from
    // the old `OpenServerDraft`, which could and did leave the rep on an
    // error screen with no way forward.
    final saved = await _repository.loadDraft();
    final references = await _repository.loadReferenceOptions();
    await _resolveRep();

    final draft = saved ?? state.draft;
    draft.applyRepDefaults(rep);
    // Derived only once the catalogues are in hand, so the price group is
    // matched against the ERP's own pairing rather than the built-in map.
    draft.applyDerivations(priceGroupResolver: references.priceGroupFor);

    _trace.step('refs', references.isFromErp ? 'from ERP' : 'built-in', {
      'synced': references.synchronisedAt?.toIso8601String(),
    });
    if (saved != null) {
      _trace.ok('draft', 'resumed from device', {
        'photos': saved.attachments.length,
      });
    }

    emit(state.copyWith(
      draft: draft,
      status: AddDepotStatus.editing,
      resumedDraft: saved != null,
      references: references,
    ));
  }

  Future<void> _onDiscardDraft(
      DiscardDraft event, Emitter<AddDepotState> emit) async {
    await _repository.clearDraft();
    _trace.step('draft', 'discarded by rep');
    emit(AddDepotState(
      currentStep: BpFormStep.identity,
      draft: BpDepotDraft()..applyRepDefaults(rep),
      references: state.references,
    ));
  }

  // ---------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------

  void _onDraftChanged(DraftChanged event, Emitter<AddDepotState> emit) {
    event.mutate(state.draft);
    state.draft
        .applyDerivations(priceGroupResolver: state.references.priceGroupFor);

    // Clear only the errors the rep has now fixed — keep the rest visible.
    final remaining = Map<String, String>.from(state.errors)
      ..removeWhere((key, _) =>
          !state.draft.validateStep(state.currentStep).containsKey(key));

    emit(state.copyWith(
      errors: remaining,
      // Any edit invalidates a previous dry run. Keeping the pass would let a
      // rep change the payment term after SAP approved the old one and submit
      // on the strength of a check that no longer applies.
      sapPreCheckPassed: false,
    ));
    _trace.step('edit',
        '${state.currentStep.number}/5 ${state.currentStep.name}', const {});
    _persistDraft();
  }

  void _onNextStep(NextStep event, Emitter<AddDepotState> emit) {
    _trace.step('next',
        '${state.currentStep.number}/6 ${state.currentStep.name}', const {});

    final errors = state.draft.validateStep(state.currentStep);
    if (errors.isNotEmpty) {
      _trace.fail(
        'step',
        '${state.currentStep.number}/6 ${state.currentStep.name}',
        {'missing': DebugTrace.names(errors.keys)},
      );
      emit(state.copyWith(errors: errors));
      return;
    }

    // The documents step needs the photographs *captured* (validateStep
    // checks that), not uploaded: nothing is sent before the rep confirms on
    // the review step, so there is no depot to upload against yet.
    if (state.isLastStep) return;

    // No network call. `Next` used to flush a patch and await the response,
    // which made advancing a step fail in a dead spot.
    final nextStep = BpFormStep.values[state.currentStep.index + 1];
    emit(state.copyWith(
      currentStep: nextStep,
      status: AddDepotStatus.editing,
      errorMessage: null,
    ));
    _trace.ok('step', '${state.currentStep.number}/6 ${state.currentStep.name}',
        const {});
    _persistDraft();
  }

  void _onPreviousStep(PreviousStep event, Emitter<AddDepotState> emit) {
    if (state.isFirstStep) return;
    emit(state.copyWith(
      currentStep: BpFormStep.values[state.currentStep.index - 1],
    ));
    _trace.step('back',
        '${state.currentStep.number}/5 ${state.currentStep.name}', const {});
  }

  /// Used by the review screen's edit pencils — jump back without re-walking.
  void _onGoToStep(GoToStep event, Emitter<AddDepotState> emit) {
    emit(state.copyWith(currentStep: event.step));
    _trace.step('jump', '${event.step.number}/5 ${event.step.name}', const {});
  }

  /// Holds the photograph on the device. Nothing is uploaded here: the
  /// documents endpoint is addressed by depot id, and the depot is only created
  /// when the rep confirms on the review step — so every photograph goes up
  /// after submit, against the record that carries the rep's final edits.
  void _onAttachmentAdded(AttachmentAdded event, Emitter<AddDepotState> emit) {
    final captured = event.attachment.copyWith(
      isUploading: false,
      isUploaded: false,
      uploadError: null,
    );
    state.draft.attachments
      ..removeWhere((a) => a.kind == event.attachment.kind)
      ..add(captured);
    emit(state.copyWith());
    _persistDraft();
  }

  /// Clears a failed upload so the photograph is sent again with the next
  /// submit. Only reachable for a draft saved by an older build, which uploaded
  /// before submit and could leave a slot marked failed.
  void _onRetryUploadAttachment(
      RetryUploadAttachment event, Emitter<AddDepotState> emit) {
    final idx = state.draft.attachments.indexWhere((a) => a.kind == event.kind);
    if (idx == -1) return;
    state.draft.attachments[idx] = state.draft.attachments[idx].copyWith(
      isUploading: false,
      isUploaded: false,
      uploadError: null,
    );
    emit(state.copyWith());
    _persistDraft();
  }

  void _onAttachmentRemoved(
      AttachmentRemoved event, Emitter<AddDepotState> emit) {
    state.draft.attachments.removeWhere((a) => a.kind == event.kind);
    emit(state.copyWith());
    _persistDraft();
  }

  /// Fire-and-forget local persistence so a killed app does not lose the form.
  void _persistDraft() {
    _trace.step('cache', 'local draft saved',
        {'step': '${state.currentStep.number}/5'});
    _repository.saveDraft(state.draft);
  }
}

/// Localisation key shown when the signed-in rep's personnel number is unknown.
const _repIdentityUnavailable = 'add_depot.error.rep_identity_unavailable';

/// No identity: the draft falls back to the documented sales-area defaults and
/// carries an empty personnel number, which the repository refuses to send.
const _noRep = RepSalesContext(
  salesOrganization: '',
  salesOrganizationName: '',
  salesOffice: '',
  salesOfficeName: '',
  salesEmployeeId: '',
  salesEmployeeName: '',
);

/// A step that failed validation, with the reasons.
class _BlockedStep {
  const _BlockedStep(this.step, this.errors);
  final BpFormStep step;
  final Map<String, String> errors;
}
