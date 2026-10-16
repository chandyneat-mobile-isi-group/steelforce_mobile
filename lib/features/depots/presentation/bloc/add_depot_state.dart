part of 'add_depot_bloc.dart';

// -----------------------------------------------------------------------------
// State
// -----------------------------------------------------------------------------
enum AddDepotStatus {
  opening,
  editing,
  validating,
  submitting,
  success,
  failure,
}

class AddDepotState {
  final BpFormStep currentStep;
  final BpDepotDraft draft;
  final AddDepotStatus status;

  /// field key -> i18n error key. Populated only after a failed Next/Submit,
  /// so the rep is not shouted at while still typing.
  final Map<String, String> errors;
  final String? errorMessage;

  /// True once the record is held on the device but not yet confirmed by SAP.
  final bool queuedOffline;

  /// True when the queued record's outcome is unknown — sent, but the answer
  /// never came — so it waits in the Sync Center for the rep to check the depot
  /// list instead of being resent automatically.
  final bool queuedNeedsReview;

  /// True when the form was restored from a draft the rep had already started,
  /// rather than opened blank. The UI says so — a pre-filled form with no
  /// explanation reads as a bug.
  final bool resumedDraft;

  /// Set once SAP has assigned a number. Empty while HQ approval is pending,
  /// so the success screen must not treat its absence as an error.
  final String? depotNumber;

  /// True when the registration was stored and is waiting on HQ approval
  /// rather than already numbered in SAP.
  ///
  /// The rep needs to be told which of the two happened: "sent for approval"
  /// and "depot 0000123456 created" are different promises, and showing the
  /// second when the first is true is how a rep comes to expect they can order
  /// against the shop today.
  final bool awaitingApproval;

  /// True when a `Commit: false` dry run last came back clean. Reset by any
  /// subsequent edit, because a form that has changed since the dry run has
  /// not been validated.
  final bool sapPreCheckPassed;

  /// Evidence slots that did not reach the server, if any.
  ///
  /// The registration still succeeded — a depot is never lost to a
  /// photograph — so this is reported alongside success rather than as a
  /// failure the rep has to clear before continuing.
  final List<DepotDocumentType> unsentDocuments;

  /// How far a submit has got. Drives the progress dialog; meaningless unless
  /// [status] is [AddDepotStatus.submitting].
  final DepotSubmitProgress progress;

  /// ERP catalogues backing the SAP-code dropdowns.
  ///
  /// Defaults to [SapReferenceOptions.empty], which resolves every dropdown to
  /// the built-in list — so the form is usable before (and without) a
  /// successful reference load.
  final SapReferenceOptions references;

  const AddDepotState({
    required this.currentStep,
    required this.draft,
    this.status = AddDepotStatus.editing,
    this.errors = const {},
    this.errorMessage,
    this.queuedOffline = false,
    this.queuedNeedsReview = false,
    this.resumedDraft = false,
    this.depotNumber,
    this.awaitingApproval = false,
    this.sapPreCheckPassed = false,
    this.references = SapReferenceOptions.empty,
    this.progress = const DepotSubmitProgress(),
    this.unsentDocuments = const [],
  });

  bool get isFirstStep => currentStep.index == 0;
  bool get isLastStep => currentStep.index == BpFormStep.values.length - 1;

  /// True while a network call owns the form and input must be inert.
  bool get isBusy =>
      status == AddDepotStatus.opening ||
      status == AddDepotStatus.validating ||
      status == AddDepotStatus.submitting;

  /// NOTE: deliberately NOT Equatable. The draft is mutable, so value equality
  /// would swallow edits. Every emit creates a new instance, and identity
  /// comparison makes bloc rebuild every time.
  AddDepotState copyWith({
    BpFormStep? currentStep,
    BpDepotDraft? draft,
    AddDepotStatus? status,
    Map<String, String>? errors,
    String? errorMessage,
    bool? queuedOffline,
    bool? queuedNeedsReview,
    bool? resumedDraft,
    String? depotNumber,
    bool? awaitingApproval,
    bool? sapPreCheckPassed,
    SapReferenceOptions? references,
    DepotSubmitProgress? progress,
    List<DepotDocumentType>? unsentDocuments,
  }) {
    return AddDepotState(
      currentStep: currentStep ?? this.currentStep,
      draft: draft ?? this.draft,
      status: status ?? this.status,
      errors: errors ?? const {},
      errorMessage: errorMessage,
      queuedOffline: queuedOffline ?? this.queuedOffline,
      queuedNeedsReview: queuedNeedsReview ?? this.queuedNeedsReview,
      resumedDraft: resumedDraft ?? this.resumedDraft,
      depotNumber: depotNumber ?? this.depotNumber,
      awaitingApproval: awaitingApproval ?? this.awaitingApproval,
      sapPreCheckPassed: sapPreCheckPassed ?? this.sapPreCheckPassed,
      references: references ?? this.references,
      progress: progress ?? this.progress,
      unsentDocuments: unsentDocuments ?? this.unsentDocuments,
    );
  }
}
