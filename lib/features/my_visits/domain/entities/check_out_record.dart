import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';

class CheckOutRecord extends Equatable {
  const CheckOutRecord({
    required this.id,
    required this.stopId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.durationMinutes,
    required this.visitSummary,
    this.checkInId,
    this.outcome,
    this.orders = const [],
    this.noOrderReason,
    this.noOrderNote,
  });

  final String id;
  final String stopId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final int durationMinutes;
  final String visitSummary;

  /// The check-in this closes (the visit id). Null when no check-in for the
  /// stop is on this device; the server then closes the stop's open visit.
  final String? checkInId;

  /// Null only on a check-out saved before outcomes existed — sent as it is,
  /// stored by the server as `unknown`.
  final CheckOutOutcome? outcome;

  /// With order: the orders taken at the stop.
  final List<VisitOrderRef> orders;

  /// Without order: a reason code from the server's list, and a note when
  /// that reason requires one.
  final String? noOrderReason;
  final String? noOrderNote;

  @override
  List<Object?> get props => [
        id,
        stopId,
        timestamp,
        latitude,
        longitude,
        durationMinutes,
        visitSummary,
        checkInId,
        outcome,
        orders,
        noOrderReason,
        noOrderNote,
      ];
}
