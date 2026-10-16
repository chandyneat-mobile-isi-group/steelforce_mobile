import 'package:equatable/equatable.dart';

enum FraudFlagType {
  mockLocation,
  impossibleSpeed,
  poorAccuracy,
  vpnDetected,

  /// A check-in the rep pushed through from outside the geofence by writing a
  /// reason. Not an accusation — the legitimate cases (a depot gate far from
  /// the office pin, a warehouse with no sky) outnumber the rest. It is here so
  /// that "how often does this rep override, and what do they write" is a
  /// question someone can answer.
  ///
  /// Safe to add: both readers resolve the name defensively
  /// (`FraudFlagModel` via `byNameOr`, the Drift mapper via `asNameMap()[..] ??`),
  /// so an older row never breaks on an unknown value.
  reasonedOverride,
}

class FraudFlag extends Equatable {
  const FraudFlag({
    required this.id,
    required this.routeId,
    required this.type,
    required this.detail,
    required this.timestamp,
    required this.blocked,
    this.stopId,
  });

  final String id;
  final String routeId;
  final String? stopId;
  final FraudFlagType type;
  final String detail;
  final DateTime timestamp;
  final bool blocked;

  @override
  List<Object?> get props => [id, routeId, stopId, type, timestamp, blocked];
}
