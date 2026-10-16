part of 'add_depot_bloc.dart';

// -----------------------------------------------------------------------------
// Events
// -----------------------------------------------------------------------------
abstract class AddDepotEvent {
  const AddDepotEvent();
}

/// The rep changed something. [mutate] writes straight onto the draft.
///
///   bloc.add(DraftChanged((d) => d.nameEn = value));
class DraftChanged extends AddDepotEvent {
  final void Function(BpDepotDraft draft) mutate;
  const DraftChanged(this.mutate);
}

/// Loads the reference catalogues and any saved form.
///
/// Named `OpenForm` rather than the old `OpenServerDraft` because nothing
/// server-side is opened any more. Both steps degrade rather than fail, so
/// unlike its predecessor this event cannot leave the form unusable.
class OpenForm extends AddDepotEvent {
  const OpenForm();
}

class NextStep extends AddDepotEvent {
  const NextStep();
}

class PreviousStep extends AddDepotEvent {
  const PreviousStep();
}

class GoToStep extends AddDepotEvent {
  final BpFormStep step;
  const GoToStep(this.step);
}

class AttachmentAdded extends AddDepotEvent {
  final BpAttachment attachment;
  const AttachmentAdded(this.attachment);
}

class RetryUploadAttachment extends AddDepotEvent {
  final String kind;
  const RetryUploadAttachment(this.kind);
}

class AttachmentRemoved extends AddDepotEvent {
  final String kind;
  const AttachmentRemoved(this.kind);
}

/// Asks SAP whether the form would be accepted, without creating anything.
///
/// Optional and rep-triggered. It costs a round trip, and the rep is the only
/// one who knows whether the connection in this shop can afford one.
class ValidateWithSap extends AddDepotEvent {
  const ValidateWithSap();
}

class SubmitToHQ extends AddDepotEvent {
  const SubmitToHQ();
}

/// Throws away the saved form and starts blank. Reachable from the resume
/// banner — a rep who is registering a different shop must be able to say so.
class DiscardDraft extends AddDepotEvent {
  const DiscardDraft();
}
