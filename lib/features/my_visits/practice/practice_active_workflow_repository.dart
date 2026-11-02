import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';

/// The visit resume pointer for a practice lesson, held in memory.
///
/// There is one pointer, not one per stop, so unlike the other stand-ins this
/// never routes by id: during a lesson it is the practice pointer only. The
/// real one is neither read nor written — a rep who was mid-visit before the
/// lesson finds that visit exactly where they left it afterwards, and the Home
/// "continue visit" card (which reads the real pointer) never offers the
/// practice visit.
///
/// Once [PracticeWorld.isClosed], every call goes to the real repository.
class PracticeActiveWorkflowRepository implements ActiveWorkflowRepository {
  PracticeActiveWorkflowRepository(this._real, this._world);

  final ActiveWorkflowRepository _real;
  final PracticeWorld _world;

  ActiveWorkflow? _workflow;

  /// The practice pointer — for tests and diagnostics.
  ActiveWorkflow? get workflow => _workflow;

  @override
  ResultFuture<ActiveWorkflow?> getActiveWorkflow() async {
    if (_world.isClosed) return _real.getActiveWorkflow();
    return Success(_workflow);
  }

  @override
  ResultFuture<void> saveActiveWorkflow(ActiveWorkflow workflow) async {
    if (_world.isClosed) return _real.saveActiveWorkflow(workflow);
    _workflow = workflow;
    return const Success(null);
  }

  @override
  ResultFuture<void> clearActiveWorkflow() async {
    if (_world.isClosed) return _real.clearActiveWorkflow();
    _workflow = null;
    return const Success(null);
  }
}
