import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';

/// Why the device cannot produce a position right now — or that it can.
///
/// Separate values rather than one `bool`, because each has a *different fix*
/// the rep can make, and the check-in dialog offers exactly that fix:
///
/// | value                    | what the rep can do                       |
/// |--------------------------|-------------------------------------------|
/// | [servicesDisabled]       | turn Location on (system settings)        |
/// | [permissionDenied]       | tap Allow on the system prompt            |
/// | [permissionDeniedForever]| enable it in the app's settings page      |
/// | [available]              | nothing — wait for the fix                |
enum LocationAvailability {
  available,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
}

/// Fast, one-shot position reads that a continuous stream cannot give.
///
/// ## Why this exists beside `LocationTrackingService`
///
/// The check-in screen used to rely on `observe()` alone — a distance-filtered
/// position *stream*. A stream only emits when the device moves past the
/// filter, so a rep standing still inside a shop can wait indefinitely for a
/// first sample, and a high-accuracy stream indoors may never produce one.
/// That is the "Waiting for a GPS fix" dialog that never resolved.
///
/// This interface adds the three reads a stream cannot do:
///
/// * [lastKnownFix] — the OS's cached position, instant, for a first reading;
/// * [currentFix] — an explicit one-shot request with a hard timeout, which a
///   stationary device still answers, and which can fall back to a coarse
///   (Wi-Fi / cell) provider that works under a roof;
/// * [checkAvailability] — so "Location is off" and "Permission denied" are
///   reported as themselves rather than as an endless search.
///
/// Kept as its **own** interface rather than new members on
/// `LocationTrackingService`, so every existing implementer and test fake of
/// that interface keeps compiling. `GeolocatorTrackingService` implements
/// both, and `LocationTrackingCubit` picks this up from it automatically.
abstract interface class LocationFixProvider {
  /// Reports whether a position can be read, requesting foreground permission
  /// first when [request] is true and it has not been decided yet.
  Future<LocationAvailability> checkAvailability({bool request = true});

  /// The OS's cached last position, or null when there is none or it is older
  /// than [maxAge]. Never touches the radio, so it returns immediately.
  Future<LocationSample?> lastKnownFix({required Duration maxAge});

  /// Asks the device for a position now.
  ///
  /// [precise] true requests satellite-grade accuracy; false accepts a
  /// network-derived fix (Wi-Fi / cell), which is what still works indoors.
  /// Returns null on [timeout] or any platform error — never throws.
  Future<LocationSample?> currentFix({
    required bool precise,
    required Duration timeout,
  });

  /// Emits true when Location Services are switched on, false when off.
  /// Empty on platforms that cannot report it.
  Stream<bool> serviceEnabledChanges();

  /// Opens the system Location settings page. False if it could not be opened.
  Future<bool> openLocationSettings();

  /// Opens this app's settings page (for a permanently denied permission).
  Future<bool> openAppSettings();
}
