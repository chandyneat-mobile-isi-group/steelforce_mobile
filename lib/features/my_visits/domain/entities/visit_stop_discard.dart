import 'package:equatable/equatable.dart';

/// Where a stop stands after the rep discarded its unsent visit work.
enum VisitStopReset {
  /// Only captures were thrown away; the stop's status did not change.
  unchanged,

  /// The check-in was thrown away; the stop is not visited again.
  notVisited,

  /// Only the check-out was thrown away; the stop is checked in again.
  checkedIn,
}

/// The outcome of discarding one stop's unsent visit work.
class VisitStopDiscard extends Equatable {
  const VisitStopDiscard({
    required this.stopId,
    required this.discardedRecords,
    required this.reset,
  });

  final String stopId;
  final int discardedRecords;
  final VisitStopReset reset;

  @override
  List<Object?> get props => [stopId, discardedRecords, reset];
}
