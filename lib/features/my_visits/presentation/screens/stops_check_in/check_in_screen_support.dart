part of '../stops_check_in_screen.dart';

// Pure helpers and constants shared by the check-in screen's parts.

const Duration _submitTimeout = Duration(seconds: 15);

/// The bloc's own, *live* copy of that stop — its status is current, unlike
/// `widget.stop`, which is the snapshot the screen was opened with.
RouteStop? _liveStop(ActiveRouteState state, String? stopId) {
  if (state is! ActiveRouteReady || stopId == null) return null;
  for (final s in state.route.stops) {
    if (s.id == stopId) return s;
  }
  return null;
}

bool _isCheckedIn(RouteStop? stop) =>
    stop != null &&
    (stop.status == VisitStatus.checkedIn ||
        stop.status == VisitStatus.checkedOut);

/// Helper to safely obtain BLoC/Cubit instances from BuildContext or Service Locator
T _resolveBloc<T extends StateStreamableSource<Object?>>(BuildContext context) {
  try {
    return context.read<T>();
  } catch (_) {
    return sl<T>();
  }
}

/// Where the designated check-in area comes from.
///
/// Each stop's own synced pin. The office demo pin is an opt-in, debug-only
/// shim — see [kUseDemoOutletPin].
const OutletLocationSource _outletLocations = kCheckInOutletLocationSource;

const FraudPolicy _policy = FraudPolicy();

List<VisitPhoto> _photosForStop(VisitState state, String stopId) {
  if (state is! VisitLoaded) return const [];
  return state.data.photos.where((p) => p.stopId == stopId).toList();
}

/// What the banner and the CTA say about the last check-in attempt.
///
/// A failed local save is rendered from its own localized key — it is not a
/// refusal the rep can reason past, and nothing was recorded.
String? _blockedReason(ActiveRouteState state) {
  if (state is! ActiveRouteReady) return null;
  if (state.checkInSaveFailed) {
    return 'my_visits.check_in_verification.save_failed'.tr;
  }
  switch (state.checkInRefusal) {
    case VisitSendStatus.alreadyVisited:
      return 'my_visits.check_in_verification.already_visited'.tr;
    case VisitSendStatus.notOnRoute:
      return 'my_visits.check_in_verification.not_on_route'.tr;
    case VisitSendStatus.sent || VisitSendStatus.queued || null:
      break;
  }
  return state.blockedCheckInReason;
}

/// A fixed stand-in for the rep while `kUseStaticCheckInPosition` is on
/// (debug builds only), so the map shows the same position the verdict
/// uses instead of the simulator's default location on another continent.
LocationSample _staticMapSample(RouteStop stop) {
  final standIn = staticCheckInPositionFor(stop.depot);
  return LocationSample(
    id: 'static-check-in-position',
    routeId: 'static',
    latitude: standIn.latitude,
    longitude: standIn.longitude,
    accuracyMeters: 0,
    speedMps: 0,
    headingDegrees: 0,
    altitudeMeters: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    isMocked: false,
  );
}

LocationSample? _mapPosition(
        RouteStop stop, LocationTrackingState locationState) =>
    kUseStaticCheckInPosition ? _staticMapSample(stop) : locationState.current;
