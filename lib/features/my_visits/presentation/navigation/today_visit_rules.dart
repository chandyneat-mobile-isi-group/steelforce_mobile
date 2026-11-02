import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_today_visit_plans.dart';

/// Today's visits as this device sees them — the server's list with the
/// check-ins and check-outs saved offline laid over it. Empty when neither
/// the server nor today's cache can say, so the server stays the last word.
Future<List<VisitPlan>> _today() async {
  if (!sl.isRegistered<GetTodayVisitPlans>()) return const [];
  return switch (await sl<GetTodayVisitPlans>()(const NoParams())) {
    Success(:final data) => data.items,
    Failed() => const [],
  };
}

/// Today's ad hoc visit at [outlet], whatever its status — completed
/// included. One ad hoc visit per outlet a day: a second is refused before
/// it reaches the server.
Future<VisitPlan?> adHocVisitToday(AdHocPlanOutlet outlet) async {
  bool same(VisitPlan p) => switch (outlet.type) {
        AdHocOutletType.depot =>
          p.depotCode?.trim() == outlet.depotCode?.trim(),
        AdHocOutletType.nonDepot =>
          p.nonDepotId?.trim() == outlet.nonDepotId?.trim(),
      };
  return (await _today()).where((p) => p.isAdHoc && same(p)).firstOrNull;
}

/// A visit other than [plan] that is checked in and neither completed nor
/// skipped. One visit at a time: none other may check in until it ends.
Future<VisitPlan?> otherOpenVisit(VisitPlan plan) async => (await _today())
    .where((p) => p.id != plan.id && p.status == VisitPlanStatus.checkedIn)
    .firstOrNull;

/// The outlets that already had their ad hoc visit today, as
/// [AdHocPlanOutlet.key]s — for showing the action as used up before it is
/// tapped. [adHocVisitToday] remains what refuses the tap.
Future<Set<String>> adHocOutletsToday() async => {
      for (final p in await _today())
        if (p.isAdHoc)
          if (p.nonDepotId?.trim() case final id? when id.isNotEmpty)
            AdHocPlanOutlet.nonDepot(id).key
          else if (p.depotCode?.trim() case final code? when code.isNotEmpty)
            AdHocPlanOutlet.depot(code).key,
    };
