import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// The server's view of one visit — the `VisitDto` of
/// `check-in-check-out-mobile.md` §8, reduced to what the app acts on.
class ServerVisit extends Equatable {
  const ServerVisit({
    required this.stopId,
    required this.status,
    this.visitId,
    this.checkedInAt,
    this.checkedOutAt,
    this.flagged = false,
  });

  /// The check-in id. Null on a stop never visited.
  final String? visitId;
  final String stopId;
  final VisitStatus status;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;

  /// Needs supervisor review (mock location, outside the geofence, …).
  final bool flagged;

  @override
  List<Object?> get props =>
      [visitId, stopId, status, checkedInAt, checkedOutAt, flagged];
}
