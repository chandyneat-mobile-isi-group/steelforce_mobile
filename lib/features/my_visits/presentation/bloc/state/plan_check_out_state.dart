import 'package:equatable/equatable.dart';
import 'package:steelforce/core/error/failures.dart';

/// Where a planned visit's check-out is.
enum PlanCheckOutStage {
  /// Waiting for the rep's tap, or for a retry after [failure].
  ready,

  /// Reading the GPS position the check-out must carry.
  locating,

  /// The request is on its way.
  sending,

  /// The server closed the visit, or the check-out waits on the device
  /// ([PlanCheckOutState.queued]).
  done,
}

/// The check-out button's state. [failure] is the last refusal and
/// [noLocation] a missing GPS fix; either is shown under the button until the
/// next attempt.
class PlanCheckOutState extends Equatable {
  const PlanCheckOutState({
    this.stage = PlanCheckOutStage.ready,
    this.failure,
    this.noLocation = false,
    this.queued = false,
  });

  final PlanCheckOutStage stage;
  final Failure? failure;
  final bool noLocation;

  /// Done, but saved on the device: it goes when the server can be reached.
  final bool queued;

  bool get busy =>
      stage == PlanCheckOutStage.locating || stage == PlanCheckOutStage.sending;

  @override
  List<Object?> get props => [stage, failure, noLocation, queued];
}
