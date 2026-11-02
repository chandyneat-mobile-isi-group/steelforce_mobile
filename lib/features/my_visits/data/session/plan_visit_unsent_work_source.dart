import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_store.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_visit_outbox_sender.dart';

/// Plan visit steps worked offline — check-ins, inventory photos and
/// check-outs — until the server has them.
///
/// Sign-out is refused while any is left; the sync engine sends them on
/// reconnect, resume and launch. Steps held after a refusal still count as
/// unsent, but not as sendable: they wait for the rep.
class PlanVisitUnsentWorkSource
    implements UnsentWorkSource, UnsentWorkBreakdown {
  const PlanVisitUnsentWorkSource({
    required PlanVisitOutboxStore store,
    required PlanVisitOutboxSender sender,
  })  : _store = store,
        _sender = sender;

  static const name = 'my_visits.plan_steps';

  final PlanVisitOutboxStore _store;
  final PlanVisitOutboxSender _sender;

  @override
  String get debugName => name;

  @override
  Future<int> countUnsent() async => (await _store.all()).length;

  /// A held step blocks the steps of its visit behind it, so only the
  /// visits with nothing held can move.
  @override
  Future<int> countSendable() async {
    final steps = await _store.all();
    final held = {
      for (final s in steps)
        if (s.needsAttention) s.planId,
    };
    return steps.where((s) => !held.contains(s.planId)).length;
  }

  @override
  Future<void> sendNow() => _sender.sendAll();

  @override
  Future<List<UnsentWorkCount>> breakdown() async {
    final steps = await _store.all();
    UnsentWorkCount count(PlanStepKind kind, UnsentWorkKind as) {
      final mine = steps.where((s) => s.kind == kind);
      return UnsentWorkCount(as, mine.length,
          needsAction: mine.where((s) => s.needsAttention).length);
    }

    return [
      count(PlanStepKind.checkIn, UnsentWorkKind.checkIns),
      count(PlanStepKind.inventory, UnsentWorkKind.visitRecords),
      count(PlanStepKind.checkOut, UnsentWorkKind.checkOuts),
    ];
  }
}
