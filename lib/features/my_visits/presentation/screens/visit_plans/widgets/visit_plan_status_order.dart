import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// Where a status sits in the day's list, top first: what the rep can still
/// do (Active — planned, or an ad hoc visit not started), then the visit in
/// progress (Checked in), then what is over (Skipped, then Completed), then
/// the rest.
int _rank(VisitPlanStatus status) => switch (status) {
      VisitPlanStatus.planned || VisitPlanStatus.draft => 0,
      VisitPlanStatus.checkedIn => 1,
      VisitPlanStatus.skipped => 2,
      VisitPlanStatus.completed => 3,
      _ => 4,
    };

/// [plans] ordered by status, top to bottom: Active, Checked in, Skipped,
/// Completed, then the rest. Stable — within a status the server's order
/// stays.
List<VisitPlan> orderVisitsByStatus(List<VisitPlan> plans) {
  final indexed = [...plans.indexed];
  indexed.sort((a, b) {
    final byStatus = _rank(a.$2.status).compareTo(_rank(b.$2.status));
    return byStatus != 0 ? byStatus : a.$1.compareTo(b.$1);
  });
  return [for (final (_, plan) in indexed) plan];
}
