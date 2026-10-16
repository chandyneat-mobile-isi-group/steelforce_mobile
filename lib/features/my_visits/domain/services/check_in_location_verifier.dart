import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';

/// Where the outlet is, for check-in verification.
///
/// A plain value rather than a reference to [DepotStopInfo] so the source of
/// the coordinates is swappable without touching the verifier: today they are
/// the static demo pin below, tomorrow they are whatever the outlet endpoint
/// returns.
class OutletLocation extends Equatable {
  const OutletLocation({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  /// Reads the pin off a synced stop — the shape this moves to once outlet
  /// coordinates arrive from the backend.
  ///
  /// Returns null when the depot has no recorded pin. `(0, 0)` is not a
  /// location, it is the Gulf of Guinea and what a handset reports when the fix
  /// failed; measuring against it would put every rep ~10 000 km away.
  static OutletLocation? forStop(
    DepotStopInfo depot, {
    required double radiusMeters,
  }) =>
      depot.hasCoordinates
          ? OutletLocation(
              latitude: depot.latitude,
              longitude: depot.longitude,
              radiusMeters: radiusMeters,
            )
          : null;

  final double latitude;
  final double longitude;

  /// The designated check-in area, in metres.
  final double radiusMeters;

  @override
  List<Object?> get props => [latitude, longitude, radiusMeters];
}

/// The verdict the check-in dialog renders and the check-in gate reads.
class CheckInLocationVerdict extends Equatable {
  const CheckInLocationVerdict._({
    required this.distanceMeters,
    required this.radiusMeters,
    required this.isWithinRadius,
    required this.hasOutletLocation,
    required this.hasDeviceFix,
  });

  /// The rep is inside the designated check-in area.
  const CheckInLocationVerdict.within({
    required double distanceMeters,
    required double radiusMeters,
  }) : this._(
          distanceMeters: distanceMeters,
          radiusMeters: radiusMeters,
          isWithinRadius: true,
          hasOutletLocation: true,
          hasDeviceFix: true,
        );

  /// Measured, and outside the area.
  const CheckInLocationVerdict.outside({
    required double distanceMeters,
    required double radiusMeters,
  }) : this._(
          distanceMeters: distanceMeters,
          radiusMeters: radiusMeters,
          isWithinRadius: false,
          hasOutletLocation: true,
          hasDeviceFix: true,
        );

  /// The device has no usable position yet.
  ///
  /// A third outcome, not a failure: the rep is not outside the area, there is
  /// simply nothing to measure from. The UI asks them to wait for a fix rather
  /// than telling them they are in the wrong place.
  const CheckInLocationVerdict.noDeviceFix({required double radiusMeters})
      : this._(
          distanceMeters: double.nan,
          radiusMeters: radiusMeters,
          isWithinRadius: false,
          hasOutletLocation: true,
          hasDeviceFix: false,
        );

  /// The outlet has no recorded pin, so there is no area to be inside of.
  const CheckInLocationVerdict.noOutletLocation({required double radiusMeters})
      : this._(
          distanceMeters: double.nan,
          radiusMeters: radiusMeters,
          isWithinRadius: false,
          hasOutletLocation: false,
          hasDeviceFix: true,
        );

  /// Metres between the rep and the outlet. `NaN` when [isMeasurable] is false
  /// — never render it without checking.
  final double distanceMeters;

  final double radiusMeters;

  /// The only thing that may enable **Confirm Check-In**.
  final bool isWithinRadius;

  final bool hasOutletLocation;
  final bool hasDeviceFix;

  /// True when [distanceMeters] is a real number worth showing.
  bool get isMeasurable => hasOutletLocation && hasDeviceFix;

  @override
  List<Object?> get props => [
        distanceMeters,
        radiusMeters,
        isWithinRadius,
        hasOutletLocation,
        hasDeviceFix
      ];
}

/// Decides whether a rep may check in, from two coordinates and a radius.
///
/// Pure and I/O-free — the same shape as [GeofenceService], which it delegates
/// the actual maths to rather than carrying a second Haversine implementation
/// that could drift from it.
///
/// ## Why this exists beside `GeofenceService`
///
/// [GeofenceService.evaluate] answers "is this rep inside *this depot's*
/// geofence", sizing the radius from the depot's territory type (urban 50 m,
/// suburban 100 m, industrial 150 m, rural 250 m). That is the production rule.
///
/// This one answers "is this rep inside *the designated check-in area*", where
/// the area is supplied by the caller. That indirection is the whole point: it
/// lets the outlet pin and the radius come from a static constant today and the
/// outlet endpoint later, without the verifier or the UI knowing which.
///
/// ```text
/// Outlet source (static today, API later)
///     ↓
/// CheckInLocationVerifier
///     ↓
/// distance + radius verdict
///     ↓
/// Check-in dialog / check-in gate
/// ```
abstract final class CheckInLocationVerifier {
  const CheckInLocationVerifier._();

  /// Verifies [deviceLatitude]/[deviceLongitude] against [outlet].
  ///
  /// Both device coordinates are required: this never invents a position, and
  /// a caller with no fix passes null and gets [CheckInLocationVerdict.noDeviceFix].
  static CheckInLocationVerdict verify({
    required OutletLocation? outlet,
    required double? deviceLatitude,
    required double? deviceLongitude,
    required double fallbackRadiusMeters,
  }) {
    if (outlet == null) {
      return CheckInLocationVerdict.noOutletLocation(
          radiusMeters: fallbackRadiusMeters);
    }
    if (deviceLatitude == null || deviceLongitude == null) {
      return CheckInLocationVerdict.noDeviceFix(
          radiusMeters: outlet.radiusMeters);
    }

    final distance = GeofenceService.distanceMeters(
      deviceLatitude,
      deviceLongitude,
      outlet.latitude,
      outlet.longitude,
    );

    // `<=`, not `<`: a rep standing exactly on the boundary is inside it. The
    // radius is the edge of the permitted area, not the first metre outside.
    return distance <= outlet.radiusMeters
        ? CheckInLocationVerdict.within(
            distanceMeters: distance, radiusMeters: outlet.radiusMeters)
        : CheckInLocationVerdict.outside(
            distanceMeters: distance, radiusMeters: outlet.radiusMeters);
  }
}
