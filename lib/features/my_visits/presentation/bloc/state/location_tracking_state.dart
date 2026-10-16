import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';

/// Where the latest search for a position stands.
///
/// This is what lets the check-in UI say something true at every moment —
/// "searching", "Location is off", "no signal here" — instead of a single
/// "Waiting for a GPS fix" that could mean any of them and never ended.
enum GpsFixStatus {
  /// Nobody has asked for a position yet.
  idle,

  /// A search is running and nothing usable has arrived yet.
  searching,

  /// A usable position is in [LocationTrackingState.current].
  acquired,

  /// Location Services are switched off on the device.
  servicesDisabled,

  /// Foreground location permission was refused (can be asked again).
  permissionDenied,

  /// Permission was refused permanently — only the app settings page helps.
  permissionDeniedForever,

  /// Services on and permission granted, but the search timed out with no
  /// fix at all (deep indoors, no Wi-Fi, no sky). The one state in which the
  /// check-in offers "Check in without GPS" — with a mandatory reason.
  unavailable,
}

class LocationTrackingState extends Equatable {
  const LocationTrackingState({
    this.isTracking = false,
    this.current,
    this.trail = const [],
    this.permissionDenied = false,
    this.fixStatus = GpsFixStatus.idle,
    this.searchStartedAt,
    this.currentReceivedAt,
  });

  /// How old [current] may be and still count as where the rep is *now*.
  ///
  /// Measured from when the app **received** it ([currentReceivedAt]), not the
  /// fix's own timestamp: some handsets report GPS time hours off the system
  /// clock, and trusting that would mark every fix stale.
  static const Duration maxUsableFixAge = Duration(minutes: 5);

  final bool isTracking;
  final LocationSample? current;
  final List<LocationSample> trail;

  /// Kept for existing readers. [fixStatus] is the richer answer.
  final bool permissionDenied;

  final GpsFixStatus fixStatus;

  /// When the current search began — drives the dialog's progress bar.
  final DateTime? searchStartedAt;

  /// When [current] arrived on this device.
  final DateTime? currentReceivedAt;

  /// [current] if it is recent enough to verify a check-in with, else null.
  LocationSample? usableFix([DateTime? now]) {
    final sample = current;
    final receivedAt = currentReceivedAt;
    if (sample == null) return null;
    // A sample with no receipt time predates this field (route stream from an
    // older state) — trust it rather than drop it.
    if (receivedAt == null) return sample;
    final age = (now ?? DateTime.now()).difference(receivedAt);
    return age <= maxUsableFixAge ? sample : null;
  }

  LocationTrackingState copyWith({
    bool? isTracking,
    LocationSample? current,
    List<LocationSample>? trail,
    bool? permissionDenied,
    GpsFixStatus? fixStatus,
    DateTime? searchStartedAt,
    DateTime? currentReceivedAt,
  }) {
    return LocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      current: current ?? this.current,
      trail: trail ?? this.trail,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fixStatus: fixStatus ?? this.fixStatus,
      searchStartedAt: searchStartedAt ?? this.searchStartedAt,
      currentReceivedAt: currentReceivedAt ?? this.currentReceivedAt,
    );
  }

  @override
  List<Object?> get props => [
        isTracking,
        current,
        trail,
        permissionDenied,
        fixStatus,
        searchStartedAt,
        currentReceivedAt,
      ];
}
