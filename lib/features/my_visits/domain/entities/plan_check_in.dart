import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// The server's refusal code for "outside the zone, send a reason". The form
/// answers it by asking for a reason, not by showing an error.
const planCheckInReasonRequiredCode = 'PLAN_CHECK_IN_REASON_REQUIRED';

/// Why a rep checks in outside the depot's zone. [apiValue] is the code
/// `POST /api/v1/mobile/plans/{id}/check-in` accepts as `reasonCode`.
enum PlanCheckInReason {
  traffic('Traffic', 'Traffic'),
  customerRequest('CustomerRequest', 'Customer request'),
  depotMoved('DepotMoved', 'Depot moved'),
  gpsAccuracy('GpsAccuracy', 'GPS accuracy'),
  roadBlocked('RoadBlocked', 'Road blocked'),
  other('Other', 'Other');

  const PlanCheckInReason(this.apiValue, this.description);

  final String apiValue;

  /// What is sent as `reasonDescription` when the rep picks this reason and
  /// writes nothing — the server requires one outside the zone. English, as
  /// the skip reasons are sent.
  final String description;

  /// The reasons a rep can pick: presets only. "Other" is left out — with no
  /// free text it would explain nothing.
  static const List<PlanCheckInReason> selectable = [
    traffic,
    customerRequest,
    depotMoved,
    gpsAccuracy,
    roadBlocked,
  ];
}

/// What the check-in needs to know about a plan before photos are sent:
/// where the depot is and how close the rep must be
/// (`GET /api/v1/mobile/plans/{id}`).
class PlanCheckInTarget extends Equatable {
  const PlanCheckInTarget({
    required this.planId,
    required this.status,
    this.depotCode,
    this.depotName,
    this.depotLatitude,
    this.depotLongitude,
    this.radiusMeters,
  });

  final String planId;
  final VisitPlanStatus status;
  final String? depotCode;
  final String? depotName;

  /// Both null when SAP has no usable location: the server then records the
  /// check-in as `NoDepotLocation` and asks for no reason.
  final double? depotLatitude;
  final double? depotLongitude;
  final double? radiusMeters;

  /// The zone used when the server sends no radius — offline, or a depot
  /// without one: within 100 m checks in plainly, beyond it needs a reason.
  static const double defaultRadiusMeters = 100;

  /// [radiusMeters], or [defaultRadiusMeters] when none was sent.
  double get zoneRadiusMeters => radiusMeters ?? defaultRadiusMeters;

  bool get hasDepotLocation => depotLatitude != null && depotLongitude != null;

  @override
  List<Object?> get props => [
        planId,
        status,
        depotCode,
        depotName,
        depotLatitude,
        depotLongitude,
        radiusMeters,
      ];
}

/// One check-in attempt. [checkInId] is generated once per visit and sent
/// again on every retry, so a lost answer never records the visit twice.
class PlanCheckInRequest extends Equatable {
  const PlanCheckInRequest({
    required this.planId,
    required this.checkInId,
    required this.latitude,
    required this.longitude,
    required this.photoPaths,
    this.accuracyMeters,
    this.reason,
    this.reasonDescription,
    this.notes,
  });

  final String planId;
  final String checkInId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  /// 1 to [maxPhotos] local files: `.jpg`, `.jpeg` or `.png`.
  final List<String> photoPaths;

  /// Both required by the server when the rep is outside the zone.
  final PlanCheckInReason? reason;
  final String? reasonDescription;

  /// Optional free text about the visit, up to [maxNotesLength].
  final String? notes;

  static const maxPhotos = 5;
  static const maxReasonLength = 500;
  static const maxNotesLength = 1000;

  @override
  List<Object?> get props => [
        planId,
        checkInId,
        latitude,
        longitude,
        accuracyMeters,
        photoPaths,
        reason,
        reasonDescription,
        notes,
      ];
}

/// The server's verdict on a check-in: `checkIn.zone` and
/// `checkIn.distanceMeters` of the 200 answer.
class PlanCheckInResult extends Equatable {
  const PlanCheckInResult({
    required this.checkInId,
    required this.zone,
    this.distanceMeters,
    this.queued = false,
  });

  /// Saved on the device to be sent when it can be; [zone] is then the
  /// device's own reading, not the server's.
  const PlanCheckInResult.queued(this.checkInId)
      : zone = '',
        distanceMeters = null,
        queued = true;

  final String checkInId;
  final bool queued;

  /// `InsideZone`, `OutsideZone` or `NoDepotLocation`, as sent.
  final String zone;
  final double? distanceMeters;

  @override
  List<Object?> get props => [checkInId, zone, distanceMeters, queued];
}
