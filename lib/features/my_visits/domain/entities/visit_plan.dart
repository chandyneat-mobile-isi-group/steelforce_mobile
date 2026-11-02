import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_sync_state.dart';

export 'package:steelforce/features/my_visits/domain/entities/plan_sync_state.dart';

/// The window `GET /api/v1/mobile/plans` answers for, in the business time
/// zone. [apiValue] is the exact `PlanPeriod` the contract accepts.
enum PlanPeriod {
  today('Today'),
  thisWeek('ThisWeek'),
  thisMonth('ThisMonth');

  const PlanPeriod(this.apiValue);

  final String apiValue;
}

/// Where a visit is in its life, as the server reports it.
///
/// The documented values are Planned, CheckedIn, Completed, Skipped and Missed
/// (`GetMyPlan`), plus Draft, Cancelled and Expired for ad hoc visits
/// (`CancelAdHocVisit`). Anything else is [unknown] — shown as the server's
/// own word rather than guessed into one of these.
enum VisitPlanStatus {
  planned,
  checkedIn,
  completed,
  skipped,
  missed,
  draft,
  cancelled,
  expired,
  unknown;

  static VisitPlanStatus fromApi(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'planned' => planned,
        'checkedin' => checkedIn,
        'completed' => completed,
        'skipped' => skipped,
        'missed' => missed,
        'draft' => draft,
        'cancelled' || 'canceled' => cancelled,
        'expired' => expired,
        _ => unknown,
      };
}

/// One visit from the rep's plan.
///
/// [id] is the **plan** id — the only identifier check-in, skip and complete
/// accept. The depot code is a property of the outlet, never a plan id.
class VisitPlan extends Equatable {
  const VisitPlan({
    required this.id,
    required this.assignmentDate,
    required this.visitType,
    required this.outletType,
    required this.status,
    required this.rawStatus,
    this.depotCode,
    this.nonDepotId,
    this.outletName,
    this.depotName,
    this.depotType,
    this.depotTier,
    this.territoryCode,
    this.latitude,
    this.longitude,
    this.syncState = PlanSyncState.synced,
    this.syncMessage,
  });

  final String id;

  /// The calendar day the visit is assigned to, at local midnight. Null only
  /// when the server sent no readable date.
  final DateTime? assignmentDate;

  /// As sent (e.g. `Planned`, `AdHoc`) — kept verbatim, not enumerated, since
  /// the contract does not list its values.
  final String visitType;

  /// `Depot` or `NonDepot`, as sent.
  final String outletType;

  final VisitPlanStatus status;

  /// The server's own status word, for display when [status] is unknown.
  final String rawStatus;

  final String? depotCode;

  /// Set for a non-depot outlet; null for a depot.
  final String? nonDepotId;

  /// Parsed but not shown: the list names a visit by [depotName].
  final String? outletName;
  final String? depotName;

  /// As sent; the contract does not list their values. Null when not sent.
  final String? depotType;
  final String? depotTier;

  /// Read only. Never sent back: the server derives territory itself.
  final String? territoryCode;

  /// The outlet's position. Both are null, or both are set and in range.
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  /// The device's own steps, not the server's word — never saved with the
  /// plan's snapshot.
  final PlanSyncState syncState;

  /// The localisation key of the refusal when [syncState] is needsAttention.
  final String? syncMessage;

  /// This plan as the device has worked it: [status] from steps saved
  /// offline, plus where those steps are.
  VisitPlan withLocalSync({
    required VisitPlanStatus status,
    required PlanSyncState syncState,
    String? syncMessage,
  }) =>
      VisitPlan(
        id: id,
        assignmentDate: assignmentDate,
        visitType: visitType,
        outletType: outletType,
        status: status,
        rawStatus: rawStatus,
        depotCode: depotCode,
        nonDepotId: nonDepotId,
        outletName: outletName,
        depotName: depotName,
        depotType: depotType,
        depotTier: depotTier,
        territoryCode: territoryCode,
        latitude: latitude,
        longitude: longitude,
        syncState: syncState,
        syncMessage: syncMessage,
      );

  /// The name to show: the depot's. Null when none came, and the card then
  /// says "Unnamed outlet" — [outletName] is deliberately not used.
  String? get displayName {
    final name = depotName?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  /// What the skip endpoint accepts: Planned or CheckedIn, and not ad hoc
  /// (those are cancelled instead). The date rule is the caller's to apply.
  bool get canSkip =>
      !isAdHoc &&
      (status == VisitPlanStatus.planned ||
          status == VisitPlanStatus.checkedIn);

  /// A visit the rep can start (check in) or carry on with — an ad hoc Draft
  /// checks in like a plan. The date rule is the caller's: only today's list
  /// offers it.
  bool get canStart =>
      status == VisitPlanStatus.planned ||
      status == VisitPlanStatus.draft ||
      status == VisitPlanStatus.checkedIn;

  bool get isAdHoc =>
      visitType.toLowerCase().replaceAll(RegExp('[^a-z]'), '') == 'adhoc';

  @override
  List<Object?> get props => [
        id,
        assignmentDate,
        visitType,
        outletType,
        status,
        rawStatus,
        depotCode,
        nonDepotId,
        outletName,
        depotName,
        depotType,
        depotTier,
        territoryCode,
        latitude,
        longitude,
        syncState,
        syncMessage,
      ];
}
