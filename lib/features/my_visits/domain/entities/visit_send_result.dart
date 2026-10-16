import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';

/// What happened when a check-in or check-out saved on the device was offered
/// to the server straight away.
enum VisitSendStatus {
  /// The server has it (or already had it — an adopted visit counts).
  sent,

  /// Offline, slow, or refused for a reason the batch push can still settle.
  /// It waits on the device and goes out with the next sync.
  queued,

  /// `409 Visit.AlreadyCompleted`: the stop was already visited today. The
  /// local check-in was dropped; nothing was recorded.
  alreadyVisited,

  /// `404 Visit.StopNotFound`: the stop is not on the rep's routes any more.
  /// The local row was dropped.
  notOnRoute,
}

class VisitSendResult extends Equatable {
  const VisitSendResult(this.status, {this.serverVisit});

  const VisitSendResult.queued() : this(VisitSendStatus.queued);

  final VisitSendStatus status;

  /// The server's view, when it answered with one.
  final ServerVisit? serverVisit;

  bool get refused =>
      status == VisitSendStatus.alreadyVisited ||
      status == VisitSendStatus.notOnRoute;

  @override
  List<Object?> get props => [status, serverVisit];
}
