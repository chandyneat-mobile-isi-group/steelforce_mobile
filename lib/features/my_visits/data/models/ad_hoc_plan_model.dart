import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/visit_plans_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// The wire shapes of `POST /api/v1/mobile/plans/ad-hoc`.
abstract final class AdHocPlanModel {
  /// The request body. Only the field that names the outlet is sent: a
  /// depot by `depotCode`, a non-depot by `nonDepotId`.
  static DataMap toJson(String visitId, AdHocPlanOutlet outlet) => {
        'visitId': visitId,
        'outletType': outlet.type.apiValue,
        if (outlet.depotCode case final code?) 'depotCode': code,
        if (outlet.nonDepotId case final id?) 'nonDepotId': id,
      };

  /// `data` of the 201/200 answer — the Draft visit, read like a plan item.
  ///
  /// The visit's id is the one the app chose, so a body without an `id`
  /// still names the visit; what it leaves out is filled from [outlet].
  static VisitPlan planFromJson(
      DataMap json, String visitId, AdHocPlanOutlet outlet) {
    final plan = VisitPlansModel.itemFromJson({
      'id': visitId,
      'visitType': 'AdHoc',
      'status': 'Draft',
      'outletType': switch (outlet.type) {
        AdHocOutletType.depot => 'Depot',
        AdHocOutletType.nonDepot => 'NonDepot',
      },
      'depotCode': outlet.depotCode,
      'nonDepotId': outlet.nonDepotId,
      for (final entry in json.entries)
        if (entry.value != null) entry.key: entry.value,
    });
    // Never null: `id` is always present above.
    return plan!;
  }
}
