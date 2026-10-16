import 'package:equatable/equatable.dart';

/// The stages a registration actually passes through on submit.
///
/// ## What is deliberately absent
///
/// There is no "sending to SAP" stage, because no such call happens.
/// `POST /mobile/depots/business-partner` writes to the platform database
/// and returns immediately; delivery to the ERP is an operator action or a
/// scheduled job, hours or days later
/// (`docs/feature/depot/mobile/create-depot.md` §Which path to use).
///
/// Animating a fake ERP step would tell a representative their shop is in SAP
/// when it is queued — and the difference matters, because a rejected push is
/// something the office fixes, not them.
enum SubmitStage {
  /// Re-checking every step, not just the visible one.
  validating,

  /// The create request that turns the draft into a depot.
  registering,

  /// Evidence photographs, one request each.
  uploadingPhotos,

  /// Server accepted the record; local cleanup.
  finishing,
}

/// How far a submit has got, for the progress dialog.
class DepotSubmitProgress extends Equatable {
  const DepotSubmitProgress({
    this.stage = SubmitStage.validating,
    this.photosSent = 0,
    this.photosTotal = 0,
  });

  final SubmitStage stage;

  /// Photographs confirmed by the server so far.
  final int photosSent;

  /// Total to send. Zero when the rep attached none, in which case the
  /// upload stage is skipped rather than shown as an instant 0/0.
  final int photosTotal;

  bool get hasPhotos => photosTotal > 0;

  /// 0..1 across the whole submit, for a determinate bar.
  ///
  /// The three fixed stages carry equal weight and the upload stage is
  /// subdivided by photo count, so a five-photo registration visibly advances
  /// rather than sitting still on one long step.
  double get fraction {
    const perStage = 1 / 3;
    return switch (stage) {
      SubmitStage.validating => 0,
      SubmitStage.registering => perStage,
      SubmitStage.uploadingPhotos =>
        perStage * 2 + (hasPhotos ? perStage * (photosSent / photosTotal) : 0),
      SubmitStage.finishing => 1,
    };
  }

  DepotSubmitProgress copyWith({
    SubmitStage? stage,
    int? photosSent,
    int? photosTotal,
  }) =>
      DepotSubmitProgress(
        stage: stage ?? this.stage,
        photosSent: photosSent ?? this.photosSent,
        photosTotal: photosTotal ?? this.photosTotal,
      );

  @override
  List<Object?> get props => [stage, photosSent, photosTotal];
}
