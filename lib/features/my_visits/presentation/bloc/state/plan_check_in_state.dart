import 'package:equatable/equatable.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';

enum PlanCheckInStage {
  /// Reading the plan's depot location.
  loading,

  /// The plan could not be read; [PlanCheckInState.failure] says why.
  loadFailed,

  /// Collecting GPS, photos and (outside the zone) a reason.
  ready,
  submitting,

  /// Checked in; [PlanCheckInState.result] holds the server's verdict.
  done,
}

/// Where the rep's GPS fix is, if anywhere.
enum PlanFixStatus { locating, found, unavailable }

/// The check-in form for one planned visit.
///
/// One class rather than a sealed family: every stage after loading shows the
/// same form, and the photos and fix must survive a failed submit.
class PlanCheckInState extends Equatable {
  const PlanCheckInState({
    this.stage = PlanCheckInStage.loading,
    this.target,
    this.fix,
    this.fixStatus = PlanFixStatus.locating,
    this.photos = const [],
    this.reasonRequired = false,
    this.failure,
    this.result,
  });

  final PlanCheckInStage stage;
  final PlanCheckInTarget? target;
  final LocationSample? fix;
  final PlanFixStatus fixStatus;

  /// Local photo paths, in capture order.
  final List<String> photos;

  /// Set when the server refused a check-in for being outside the zone.
  final bool reasonRequired;

  /// The last load or submit failure, for a message. Cleared on retry.
  final Failure? failure;
  final PlanCheckInResult? result;

  /// Metres from the depot, or null without a fix or a depot location.
  double? get distanceMeters {
    final t = target;
    final f = fix;
    if (t == null || f == null || !t.hasDepotLocation) return null;
    return GeofenceService.distanceMeters(
        f.latitude, f.longitude, t.depotLatitude!, t.depotLongitude!);
  }

  /// True when the fix is farther than the depot's radius. The server makes
  /// the final call; this only lets the form ask for a reason up front.
  bool get outsideZone {
    final d = distanceMeters;
    final radius = target?.zoneRadiusMeters;
    return d != null && radius != null && d > radius;
  }

  bool get needsReason => reasonRequired || outsideZone;

  bool get canAddPhoto => photos.length < PlanCheckInRequest.maxPhotos;

  PlanCheckInState copyWith({
    PlanCheckInStage? stage,
    PlanCheckInTarget? target,
    LocationSample? fix,
    PlanFixStatus? fixStatus,
    List<String>? photos,
    bool? reasonRequired,
    Failure? Function()? failure,
    PlanCheckInResult? result,
  }) =>
      PlanCheckInState(
        stage: stage ?? this.stage,
        target: target ?? this.target,
        fix: fix ?? this.fix,
        fixStatus: fixStatus ?? this.fixStatus,
        photos: photos ?? this.photos,
        reasonRequired: reasonRequired ?? this.reasonRequired,
        failure: failure == null ? this.failure : failure(),
        result: result ?? this.result,
      );

  @override
  List<Object?> get props => [
        stage,
        target,
        fix,
        fixStatus,
        photos,
        reasonRequired,
        failure,
        result,
      ];
}
