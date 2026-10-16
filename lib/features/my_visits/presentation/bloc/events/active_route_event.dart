import 'package:equatable/equatable.dart';

sealed class ActiveRouteEvent extends Equatable {
  const ActiveRouteEvent();
  @override
  List<Object?> get props => [];
}

final class ActiveRouteLoadRequested extends ActiveRouteEvent {
  const ActiveRouteLoadRequested(this.routeId);
  final String routeId;
  @override
  List<Object?> get props => [routeId];
}

final class StartDayRequested extends ActiveRouteEvent {
  const StartDayRequested();
}

final class StopSelected extends ActiveRouteEvent {
  const StopSelected(this.index);
  final int index;
  @override
  List<Object?> get props => [index];
}

/// Fed continuously by the screen's `BlocListener<LocationTrackingCubit,...>`
/// — recomputed via `GeofenceService` on every GPS sample, so the bloc
/// always knows whether the rep is currently inside the selected stop's
/// geofence without depending on `LocationTrackingCubit` directly.
final class GeofenceStatusChanged extends ActiveRouteEvent {
  const GeofenceStatusChanged({
    required this.insideGeofence,
    required this.distanceMeters,
    required this.accuracyMeters,
    required this.isMocked,
    required this.latitude,
    required this.longitude,
    this.depotLocationKnown = true,
  });

  final bool insideGeofence;
  final double distanceMeters;
  final double accuracyMeters;
  final bool isMocked;
  final double latitude;
  final double longitude;

  /// False when the *depot* has no recorded position, in which case
  /// [insideGeofence] and [distanceMeters] carry no meaning.
  ///
  /// A third outcome, not a failure — `GeofenceService.evaluate` says the same
  /// thing in its own docs. The rep is not outside the geofence; there is no
  /// geofence. Without carrying this through, an ungeotagged shop reaches the
  /// bloc as `insideGeofence: false` and blocks a rep who is standing in
  /// exactly the right place.
  final bool depotLocationKnown;

  @override
  List<Object?> get props => [
        insideGeofence,
        distanceMeters,
        accuracyMeters,
        isMocked,
        latitude,
        longitude,
        depotLocationKnown,
      ];
}

final class CheckInRequested extends ActiveRouteEvent {
  const CheckInRequested({this.overrideReason, this.stopId});

  /// The stop being checked in to. When set, the bloc checks in **this** stop
  /// rather than whatever `currentStopIndex` happens to point at — the screen
  /// always knows its stop, and a `StopSelected` still in flight must not
  /// redirect the check-in to a different one.
  final String? stopId;

  /// The rep's written justification for checking in from outside the
  /// geofence, or on a fix too coarse to judge.
  ///
  /// Null on an ordinary check-in. When present and long enough
  /// (`FraudPolicy.minOverrideReasonLength`), it carries the check-in past the
  /// two location-derived rules — and only those. It is recorded, not
  /// consumed: a `VisitNote` goes with the visit and a `FraudFlag` goes in the
  /// audit trail, so an override is always visible afterwards.
  final String? overrideReason;

  @override
  List<Object?> get props => [overrideReason, stopId];
}

final class CheckOutRequested extends ActiveRouteEvent {
  const CheckOutRequested(this.visitSummary);
  final String visitSummary;
  @override
  List<Object?> get props => [visitSummary];
}

final class NextStopRequested extends ActiveRouteEvent {
  const NextStopRequested();
}

/// Skip a specific stop [index] (before or during the route), recording the
/// rep's [reason]. The stop is marked [VisitStatus.missed]; the reason is kept
/// in state so the timeline can show why it was skipped.
final class SkipStopRequested extends ActiveRouteEvent {
  const SkipStopRequested({required this.index, required this.reason});
  final int index;
  final String reason;
  @override
  List<Object?> get props => [index, reason];
}

final class EndDayRequested extends ActiveRouteEvent {
  const EndDayRequested();
}
