import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_store.dart';
import 'package:steelforce/features/my_visits/data/local/visit_plan_local_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';
import 'package:steelforce/features/my_visits/domain/repositories/pending_plan_visits_source.dart';

/// The plan visit outbox, one entry per visit, for the Sync Center.
///
/// The outbox knows a plan only by id; the depot's name comes from what this
/// device kept of the plan — its check-in target, else today's list.
class PlanVisitPendingReader implements PendingPlanVisitsSource {
  const PlanVisitPendingReader({
    required PlanVisitOutboxStore store,
    required VisitPlanLocalDataSource local,
  })  : _store = store,
        _local = local;

  final PlanVisitOutboxStore _store;
  final VisitPlanLocalDataSource _local;

  @override
  Stream<List<PendingPlanVisit>> watch() => _store.watch().asyncMap(_group);

  Future<List<PendingPlanVisit>> _group(List<PlanOutboxStep> steps) async {
    if (steps.isEmpty) return const [];
    final byPlan = <String, List<PlanOutboxStep>>{};
    for (final step in steps) {
      byPlan.putIfAbsent(step.planId, () => []).add(step);
    }
    final names = await _names(byPlan.keys);
    final visits = [
      for (final MapEntry(key: planId, value: mine) in byPlan.entries)
        _summarise(planId, mine, names[planId]),
    ]..sort((a, b) => a.since.compareTo(b.since));
    return visits;
  }

  static PendingPlanVisit _summarise(
      String planId, List<PlanOutboxStep> steps, String? depotName) {
    final held = steps.where((s) => s.needsAttention).firstOrNull;
    return PendingPlanVisit(
      planId: planId,
      since:
          steps.map((s) => s.createdAt).reduce((a, b) => a.isBefore(b) ? a : b),
      depotName: depotName,
      checkIn: steps.any((s) => s.kind == PlanStepKind.checkIn),
      photos: steps
          .where((s) => s.kind == PlanStepKind.inventory)
          .fold(0, (n, s) => n + s.photoPaths.length),
      checkOut: steps.any((s) => s.kind == PlanStepKind.checkOut),
      needsAttention: held != null,
      messageKey: held?.errorMessage,
      steps: [
        for (final s in [
          ...steps
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
          PendingPlanStep(
            kind: switch (s.kind) {
              PlanStepKind.checkIn => PendingPlanStepKind.checkIn,
              PlanStepKind.inventory => PendingPlanStepKind.inventory,
              PlanStepKind.checkOut => PendingPlanStepKind.checkOut,
            },
            savedAt: s.createdAt,
            photoPaths: s.photoPaths,
          ),
      ],
    );
  }

  /// Best effort: a name the cache cannot give is simply left out.
  Future<Map<String, String>> _names(Iterable<String> planIds) async {
    final names = <String, String>{};
    try {
      final today = (await _local.read(VisitPlanCacheKeys.today))?.items;
      for (final id in planIds) {
        final kept = (await _local.readTarget(id))?.target.depotName;
        final listed = today?.where((p) => p.id == id).firstOrNull?.displayName;
        final name = (kept?.trim().isNotEmpty ?? false) ? kept : listed;
        if (name != null && name.trim().isNotEmpty) names[id] = name;
      }
    } on Object {
      // The steps still show, under a generic title.
    }
    return names;
  }
}
