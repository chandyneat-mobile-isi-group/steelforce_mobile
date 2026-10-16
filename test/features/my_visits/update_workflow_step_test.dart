import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_workflow_step.dart';

/// `navigationArguments` is one shared map written by several callers: check-in
/// seeds `stopId`/`territory`, and individual guided steps add state of their
/// own (a half-finished stock audit). Whoever writes last must not erase what
/// the others put there.
///
/// This used to *replace* the map, which is why a stock count that appeared to
/// save was gone by the next route event — the rep's taps were persisted and
/// then immediately overwritten by a baseline write that knew nothing about
/// them. The bug is invisible in the UI until you leave the screen and come
/// back, so it is pinned here rather than left to manual testing.
class _FakeRepo implements ActiveWorkflowRepository {
  _FakeRepo(this.stored);

  ActiveWorkflow? stored;
  ActiveWorkflow? lastSaved;

  @override
  ResultFuture<ActiveWorkflow?> getActiveWorkflow() async => Success(stored);

  @override
  ResultFuture<void> saveActiveWorkflow(ActiveWorkflow workflow) async {
    lastSaved = workflow;
    stored = workflow;
    return const Success(null);
  }

  @override
  ResultFuture<void> clearActiveWorkflow() async => const Success(null);
}

ActiveWorkflow _checkedIn(Map<String, dynamic> args) => ActiveWorkflow(
      routeId: 'r1',
      currentStopId: 's1',
      dayStarted: true,
      updatedAt: DateTime(2026, 8, 20),
      depotId: 'c1',
      currentWorkflow: VisitWorkflow.stockCount,
      navigationArguments: args,
    );

void main() {
  test('merges incoming arguments onto the ones already recorded', () async {
    final repo = _FakeRepo(_checkedIn({
      'stopId': 's1',
      'depotId': 'c1',
      'territory': 'PP',
    }));

    await UpdateWorkflowStep(repo)(UpdateWorkflowStepParams(
      VisitWorkflow.stockCount,
      screen: 'my-visits-inventory-visibility',
      navigationArguments: {
        'depotId': 'c1',
        'stockAudit': {'1': 'high', '2': 'low'},
      },
    ));

    final args = repo.lastSaved!.navigationArguments!;
    // The step's own state is stored...
    expect(args['stockAudit'], {'1': 'high', '2': 'low'});
    // ...without dropping the keys check-in wrote, which the resume
    // dispatcher's fallbacks read.
    expect(args['stopId'], 's1');
    expect(args['territory'], 'PP');
  });

  test('incoming keys win over stored ones', () async {
    final repo = _FakeRepo(_checkedIn({'depotName': 'Old Depot'}));

    await UpdateWorkflowStep(repo)(UpdateWorkflowStepParams(
      VisitWorkflow.stockCount,
      navigationArguments: {'depotName': 'New Depot'},
    ));

    expect(repo.lastSaved!.navigationArguments!['depotName'], 'New Depot');
  });

  test('null arguments leave the stored map untouched', () async {
    // A caller recording only a screen change must not blank the map.
    final repo = _FakeRepo(_checkedIn({'stopId': 's1'}));

    await UpdateWorkflowStep(repo)(const UpdateWorkflowStepParams(
      VisitWorkflow.quotation,
      screen: 'quotation-builder',
    ));

    expect(repo.lastSaved!.navigationArguments, {'stopId': 's1'});
    expect(repo.lastSaved!.currentScreen, 'quotation-builder');
  });

  test('does nothing when there is no active visit', () async {
    final repo = _FakeRepo(null);

    await UpdateWorkflowStep(repo)(const UpdateWorkflowStepParams(
      VisitWorkflow.stockCount,
    ));

    expect(repo.lastSaved, isNull,
        reason: 'nothing to attach a step to before check-in');
  });
}
