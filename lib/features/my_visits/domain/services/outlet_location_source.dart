import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/services/check_in_location_verifier.dart';

/// Where the check-in area for an outlet comes from.
///
/// One interface with two implementations. The check-in flow uses
/// [StopOutletLocationSource] — the synced stop's own pin — via
/// [kCheckInOutletLocationSource]; [StaticOutletLocationSource] (a fixed demo
/// pin) survives only as an opt-in, debug-only office-testing shim
/// ([kUseDemoOutletPin]).
///
/// ```text
/// StopOutletLocationSource  (the stop's own pin; null when it has none)
///          ↓
/// CheckInLocationVerifier
///          ↓
/// distance + radius verdict  (or "outlet location unavailable")
/// ```
abstract interface class OutletLocationSource {
  /// The designated check-in area for [depot], or null when there is none
  /// to measure against.
  OutletLocation? locationFor(DepotStopInfo depot);

  /// The radius used when [locationFor] cannot produce a location — so the UI
  /// can still say what the rule *would* have been.
  double get radiusMeters;
}

/// The check-in radius for this build: **100 m**.
///
/// Deliberately one constant rather than a per-territory figure. The
/// territory-sized radii on `TerritoryType` (urban 50 m … rural 250 m) remain
/// the production rule for `GeofenceService`, but a demo pin has no territory
/// worth honouring, and a dialog that said "within" at 85 m while the
/// underlying check refused at 50 m would be worse than either rule alone.
const double kCheckInRadiusMeters = 100;

/// A fixed pin, for demonstrating and testing the check-in flow before outlet
/// coordinates exist on the backend.
///
/// Every rep verifies against the same point regardless of which stop they
/// opened. That is correct *for a demo* and wrong for anything else, so the
/// flow only uses it when [kUseDemoOutletPin] is on (debug builds, opt-in).
///
/// The coordinates are ISI's Phnom Penh office.
class StaticOutletLocationSource implements OutletLocationSource {
  const StaticOutletLocationSource({
    this.latitude = kDemoOutletLatitude,
    this.longitude = kDemoOutletLongitude,
    this.radiusMeters = kCheckInRadiusMeters,
  });

  static const double kDemoOutletLatitude = 11.5564;
  static const double kDemoOutletLongitude = 104.9282;

  final double latitude;
  final double longitude;

  @override
  final double radiusMeters;

  @override
  OutletLocation? locationFor(DepotStopInfo depot) => OutletLocation(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
}

/// The real thing: verify against the stop's own synced pin. What the check-in
/// flow uses ([kCheckInOutletLocationSource]).
///
/// Returns null for a depot with no pin, which the verifier reports as
/// "no outlet location" rather than measuring against `(0, 0)`.
class StopOutletLocationSource implements OutletLocationSource {
  const StopOutletLocationSource({this.radiusMeters = kCheckInRadiusMeters});

  @override
  final double radiusMeters;

  @override
  OutletLocation? locationFor(DepotStopInfo depot) =>
      OutletLocation.forStop(depot, radiusMeters: radiusMeters);
}

/// TODO(release-gate): take the rep's position from a constant, not the GPS.
///
/// **Debug builds only.** On by default in debug, switchable off with
/// `--dart-define=STATIC_CHECK_IN_POSITION=false`. ANDed with [kDebugMode] so
/// no dart-define can turn it on in a profile or release build: a default of
/// [kDebugMode] alone still let `=true` fake check-in GPS in release.
///
/// ## What this replaces
///
/// The rep's own position, everywhere it is used in the check-in flow:
///
/// * the distance the verification dialog measures and shows, and
/// * the `latitude`/`longitude` stamped on the pushed check-in row.
///
/// Both come from [kStaticCheckInPosition] instead of the device. That is the
/// point: on a simulator, or any handset that has not been granted location,
/// there is no fix — so the dialog would sit on "Locating You" and no check-in
/// could ever be made. This makes the whole flow exercisable without GPS.
///
/// ## What it costs
///
/// `latitude`/`longitude` on a check-in are the geofence evidence the **server**
/// judges the visit on (api.md §8.2). `ActiveRouteBloc` normally sends the
/// rep's measured position for exactly that reason — an earlier version sent
/// the shop's own pin, which made every check-in arrive reading as precisely
/// on-location whoever sent it, and left the server-side check structurally
/// incapable of catching anything.
///
/// With this on, that is deliberately true again, and the rep is also *shown* a
/// distance nobody measured. Neither is acceptable in a rep's hands; both are
/// exactly what is wanted while the outlet feed and location permissions are
/// still being built. It must be off before release.
///
/// ## Demo builds
///
/// TODO(release-gate): demo-only geofence bypass. Also on in any build with
/// `USE_MOCK_DATA=true` ([DataSourceMode.useMocks]), whatever its build mode,
/// because a presenter showing the visit journey is never at the demo
/// depots. That cannot weaken a live build: the flag is compile-time, a build
/// that sets it registers demo data sources only, and every `dio` client in
/// it refuses to send (`DemoNetworkGuardAdapter`) — a check-in it records has
/// no server to reach.
const bool kUseStaticCheckInPosition = DataSourceMode.useMocks ||
    (kDebugMode &&
        bool.fromEnvironment('STATIC_CHECK_IN_POSITION', defaultValue: true));

/// Opt-in, debug-only: measure every stop against the fixed demo pin
/// ([StaticOutletLocationSource] — ISI's Phnom Penh office) instead of the
/// stop's own synced pin.
///
/// TODO(release-gate): office-testing shim. It makes every rep in every shop
/// verify against one point, which is meaningless in the field. Gated on
/// `kDebugMode` so a profile or release build can never enable it, and off by
/// default even in debug — build with `--dart-define=USE_DEMO_OUTLET_PIN=true`
/// to turn it on.
///
/// Replaces the earlier `USE_STOP_OUTLET_PIN` flag, which had it the wrong way
/// round: the office pin was the default in **every** build, so a rep standing
/// at the real shop read as "outside" and the 100 m radius was never measured
/// against the outlet at all.
const bool kUseDemoOutletPin =
    kDebugMode && bool.fromEnvironment('USE_DEMO_OUTLET_PIN');

/// The outlet source the check-in flow measures against.
///
/// The stop's own synced pin ([StopOutletLocationSource]). A stop with no pin
/// produces no location, which the verifier reports as
/// `CheckInLocationVerdict.noOutletLocation` — the flow's existing
/// "outlet location unavailable" state — rather than falling back to the
/// office.
const OutletLocationSource kCheckInOutletLocationSource = kUseDemoOutletPin
    ? StaticOutletLocationSource()
    : StopOutletLocationSource();

/// The rep's stand-in position while [kUseStaticCheckInPosition] is on.
///
/// Defaults to the demo outlet pin. [staticCheckInPositionFor] is what the flow
/// actually reads: it places the stand-in rep on the stop's own pin, so the
/// verdict is **0 m — within the check-in radius** and a check-in can be
/// completed end to end with no GPS.
///
/// To exercise the *outside* path — the reason sheet, the `reasonedOverride`
/// fraud flag, the reason on the pushed row — build with
/// `--dart-define=USE_DEMO_OUTLET_PIN=true` and move this far enough out.
/// Roughly 250 m north of the pin:
///
/// ```dart
/// const kStaticCheckInPosition = (latitude: 11.5586, longitude: 104.9282);
/// ```
const ({double latitude, double longitude}) kStaticCheckInPosition = (
  latitude: StaticOutletLocationSource.kDemoOutletLatitude,
  longitude: StaticOutletLocationSource.kDemoOutletLongitude,
);

/// Where the stand-in rep "stands" for [depot] while
/// [kUseStaticCheckInPosition] is on (debug builds only).
///
/// On the outlet's own pin when it has one and [kUseDemoOutletPin] is off —
/// the outlet source measures against that same pin. Otherwise
/// [kStaticCheckInPosition]. For a stop with no pin the verdict is "outlet
/// location unavailable" regardless of where the rep stands.
({double latitude, double longitude}) staticCheckInPositionFor(
  DepotStopInfo depot,
) =>
    !kUseDemoOutletPin && depot.hasCoordinates
        ? (latitude: depot.latitude, longitude: depot.longitude)
        : kStaticCheckInPosition;
