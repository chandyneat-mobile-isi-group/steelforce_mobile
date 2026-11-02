import 'package:equatable/equatable.dart';

/// A planned visit with steps saved on this device that the server does not
/// have yet — check-in, inventory photos, check-out — for the Sync Center.
class PendingPlanVisit extends Equatable {
  const PendingPlanVisit({
    required this.planId,
    required this.since,
    this.depotName,
    this.checkIn = false,
    this.photos = 0,
    this.checkOut = false,
    this.needsAttention = false,
    this.messageKey,
    this.steps = const [],
  });

  final String planId;

  /// When the oldest waiting step was saved.
  final DateTime since;

  /// Null when this device no longer holds the plan.
  final String? depotName;

  /// The check-in is waiting.
  final bool checkIn;

  /// Inventory photos waiting, across every upload.
  final int photos;

  /// The check-out is waiting.
  final bool checkOut;

  /// The server refused a step; it and the steps after it wait for the rep.
  final bool needsAttention;

  /// The localisation key for the refusal while [needsAttention].
  final String? messageKey;

  /// Each waiting step, in the order it will be sent.
  final List<PendingPlanStep> steps;

  @override
  List<Object?> get props => [
        planId,
        since,
        depotName,
        checkIn,
        photos,
        checkOut,
        needsAttention,
        messageKey,
        steps,
      ];
}

enum PendingPlanStepKind { checkIn, inventory, checkOut }

/// One step of a [PendingPlanVisit] still on the device.
class PendingPlanStep extends Equatable {
  const PendingPlanStep({
    required this.kind,
    required this.savedAt,
    this.photoPaths = const [],
  });

  final PendingPlanStepKind kind;
  final DateTime savedAt;

  /// The device's own copies of the step's photos. Shown on this device
  /// only, never logged.
  final List<String> photoPaths;

  @override
  List<Object?> get props => [kind, savedAt, photoPaths];
}
