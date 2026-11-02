import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// `outletType` of `POST /api/v1/mobile/plans/ad-hoc`, as the number the
/// contract takes.
///
/// The Swagger example shows `1` and names the values Depot and NonDepot;
/// Depot = 1, NonDepot = 2 is read from that and needs the backend's word.
enum AdHocOutletType {
  depot(1),
  nonDepot(2);

  const AdHocOutletType(this.apiValue);

  final int apiValue;
}

/// The outlet an ad hoc visit is started at: a depot by its code, or a
/// non-depot by its id — never both.
class AdHocPlanOutlet extends Equatable {
  const AdHocPlanOutlet.depot(String this.depotCode)
      : type = AdHocOutletType.depot,
        nonDepotId = null;

  const AdHocPlanOutlet.nonDepot(String this.nonDepotId)
      : type = AdHocOutletType.nonDepot,
        depotCode = null;

  final AdHocOutletType type;
  final String? depotCode;
  final String? nonDepotId;

  /// One per outlet, so a retry of the same outlet reuses its visit id.
  String get key => '${type.name}:${depotCode ?? nonDepotId}';

  @override
  List<Object?> get props => [type, depotCode, nonDepotId];
}

/// What came of starting an ad hoc visit. A refusal is a `Failure` instead.
sealed class AdHocPlanOutcome extends Equatable {
  const AdHocPlanOutcome();
}

/// The server holds the visit as a Draft plan — newly made, or the same one
/// again when this start was already sent ([created] false).
final class AdHocPlanStarted extends AdHocPlanOutcome {
  const AdHocPlanStarted({required this.plan, required this.created});

  final VisitPlan plan;
  final bool created;

  @override
  List<Object?> get props => [plan, created];
}

/// `PLAN_ALREADY_VISITED_TODAY`: the outlet is already on today. Not an
/// error — [planId] names the visit that is there, when the server sends it.
final class AdHocPlanAlreadyToday extends AdHocPlanOutcome {
  const AdHocPlanAlreadyToday({this.planId});

  final String? planId;

  @override
  List<Object?> get props => [planId];
}
