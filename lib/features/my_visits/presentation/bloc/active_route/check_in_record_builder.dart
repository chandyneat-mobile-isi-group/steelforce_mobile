import 'dart:math';

import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/services/outlet_location_source.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';

/// A locally unique id for a row the route flow writes (check-in, check-out,
/// fraud flag).
String newRouteEventId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';

/// The check-in row for [stop], as measured in [current].
CheckInRecord buildCheckInRecord({
  required ActiveRouteReady current,
  required RouteStop stop,
  required DateTime now,
  required String? overrideReason,
}) =>
    CheckInRecord(
      id: newRouteEventId(),
      stopId: stop.id,
      timestamp: now,
      // **The rep's position, not the shop's.** These two fields are the
      // geofence evidence the server judges the visit on (api.md §8.2), and
      // this used to send `stop.depot.latitude/longitude` — the shop's own
      // pin. Every check-in then arrived reading as exactly on-location,
      // whoever sent it and from wherever, which makes the server-side check
      // structurally incapable of catching anything.
      //
      // Falls back to the depot pin only when there is no fix at all, and
      // that row is already flagged unverified in the warnings, so the
      // server can tell the difference between measured and assumed.
      //
      // TODO(release-gate): `kUseStaticCheckInPosition` replaces both with a
      // stand-in (the stop's own pin) in debug builds so the push contract can
      // be exercised without a usable GPS. It is `kDebugMode`-gated and cannot
      // reach release, but while it is on every check-in reports itself as
      // exactly on-location — see the flag's own doc for what that costs.
      latitude: kUseStaticCheckInPosition
          ? staticCheckInPositionFor(stop.depot).latitude
          : current.repLatitude ?? stop.depot.latitude,
      longitude: kUseStaticCheckInPosition
          ? staticCheckInPositionFor(stop.depot).longitude
          : current.repLongitude ?? stop.depot.longitude,
      accuracyMeters: current.accuracyMeters,
      distanceFromDepotMeters: current.distanceMeters,
      isMocked: current.isMocked,
      overrideReason: overrideReason,
      routeId: current.route.id,
    );
