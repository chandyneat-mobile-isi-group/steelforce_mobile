import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';

sealed class ActiveRouteState extends Equatable {
  const ActiveRouteState();
  @override
  List<Object?> get props => [];
}

final class ActiveRouteLoading extends ActiveRouteState {
  const ActiveRouteLoading();
}

final class ActiveRouteReady extends ActiveRouteState {
  const ActiveRouteReady({
    required this.route,
    required this.dayStarted,
    required this.currentStopIndex,
    this.insideGeofence = true,
    this.distanceMeters = 0,
    this.accuracyMeters = 0,
    this.isMocked = false,
    this.blockedCheckInReason,
    this.checkInWarnings = const [],
    this.skipReasons = const {},
    this.repLatitude,
    this.repLongitude,
    this.depotLocationKnown = true,
    this.checkInOverridable = false,
    this.checkInAttempt = 0,
    this.checkInSaveFailed = false,
    this.checkInRefusal,
  });

  final RoutePlan route;
  final bool dayStarted;
  final int currentStopIndex;
  final bool insideGeofence;
  final double distanceMeters;
  final double accuracyMeters;
  final bool isMocked;
  final String? blockedCheckInReason;
  final List<String> checkInWarnings;

  /// Reasons the rep gave when skipping a stop, keyed by stop id. Session-scoped
  /// display data (the skip itself persists as [VisitStatus.missed]).
  final Map<String, String> skipReasons;

  /// The rep's own last known position, from the live GPS stream.
  ///
  /// **Null until a fix arrives**, which is the state that matters: a check-in
  /// written before the first fix has no evidence of where the rep was, and
  /// recording the shop's own coordinates in its place — which is what this
  /// used to do — makes every visit look perfectly on-location and renders the
  /// geofence evidence in api.md §8.2 incapable of catching anything.
  final double? repLatitude;
  final double? repLongitude;

  /// False when the selected stop's depot has no recorded coordinates.
  ///
  /// Distinct from [insideGeofence] being false. There is nothing to be
  /// outside of, so check-in proceeds and records itself as unverifiable
  /// rather than blocking a rep standing in the right place at a shop nobody
  /// has geotagged.
  final bool depotLocationKnown;

  /// True once the device has produced at least one position.
  bool get hasFix => repLatitude != null && repLongitude != null;

  /// True when the current [blockedCheckInReason] is one a written reason
  /// could carry the rep past — outside the geofence, or a fix too coarse to
  /// judge, and no integrity rule among the blocks.
  ///
  /// The screen reads this to decide between offering "Check in anyway" and
  /// simply reporting the block. Carried as a flag rather than re-derived in
  /// the UI, because the alternative is matching on the text of the reason
  /// string, which breaks the first time someone rewords it or translates it.
  final bool checkInOverridable;

  /// Increments every time a `CheckInRequested` is answered — success, block,
  /// already-checked-in, or save failure.
  ///
  /// **Why it exists.** The screen waits for the bloc's answer before moving
  /// on. Bloc never emits a state equal to the current one, so a second
  /// refusal with the same reason as the first, or a check-in on a stop that
  /// was already checked in, produced *no* emission at all — and the
  /// "Check-in & Continue" spinner ran forever. A counter that always moves
  /// guarantees every attempt gets an answer the screen can see.
  final int checkInAttempt;

  /// True when the last check-in attempt passed every rule but its local save
  /// failed, so **nothing was recorded**.
  ///
  /// A typed flag rather than another English sentence in
  /// [blockedCheckInReason]: the screen renders its own localized message
  /// for it (state carries no presentation strings), and it is distinct from
  /// a refusal — there is nothing for the rep to fix but to try again.
  final bool checkInSaveFailed;

  /// The server definitively refused the last check-in — the stop was already
  /// visited today, or is not on the rep's routes any more. Nothing was
  /// recorded. A typed value for the same reason as [checkInSaveFailed]: the
  /// screen renders its own localized message.
  final VisitSendStatus? checkInRefusal;

  bool get hasCurrentStop =>
      currentStopIndex >= 0 && currentStopIndex < route.stops.length;

  ActiveRouteReady copyWith({
    RoutePlan? route,
    bool? dayStarted,
    int? currentStopIndex,
    bool? insideGeofence,
    double? distanceMeters,
    double? accuracyMeters,
    bool? isMocked,
    String? Function()? blockedCheckInReason,
    List<String>? checkInWarnings,
    Map<String, String>? skipReasons,
    double? repLatitude,
    double? repLongitude,
    bool? depotLocationKnown,
    bool? checkInOverridable,
    int? checkInAttempt,
    bool? checkInSaveFailed,
    VisitSendStatus? Function()? checkInRefusal,
  }) {
    return ActiveRouteReady(
      route: route ?? this.route,
      dayStarted: dayStarted ?? this.dayStarted,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      insideGeofence: insideGeofence ?? this.insideGeofence,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      isMocked: isMocked ?? this.isMocked,
      blockedCheckInReason: blockedCheckInReason != null
          ? blockedCheckInReason()
          : this.blockedCheckInReason,
      checkInWarnings: checkInWarnings ?? this.checkInWarnings,
      skipReasons: skipReasons ?? this.skipReasons,
      repLatitude: repLatitude ?? this.repLatitude,
      repLongitude: repLongitude ?? this.repLongitude,
      depotLocationKnown: depotLocationKnown ?? this.depotLocationKnown,
      checkInOverridable: checkInOverridable ?? this.checkInOverridable,
      checkInAttempt: checkInAttempt ?? this.checkInAttempt,
      checkInSaveFailed: checkInSaveFailed ?? this.checkInSaveFailed,
      checkInRefusal:
          checkInRefusal != null ? checkInRefusal() : this.checkInRefusal,
    );
  }

  @override
  List<Object?> get props => [
        route,
        dayStarted,
        currentStopIndex,
        insideGeofence,
        distanceMeters,
        isMocked,
        blockedCheckInReason,
        checkInWarnings,
        skipReasons,
        repLatitude,
        repLongitude,
        depotLocationKnown,
        checkInOverridable,
        checkInAttempt,
        checkInSaveFailed,
        checkInRefusal,
      ];
}

final class ActiveRouteCompleted extends ActiveRouteState {
  const ActiveRouteCompleted(this.route);
  final RoutePlan route;
  @override
  List<Object?> get props => [route];
}

final class ActiveRouteError extends ActiveRouteState {
  const ActiveRouteError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
