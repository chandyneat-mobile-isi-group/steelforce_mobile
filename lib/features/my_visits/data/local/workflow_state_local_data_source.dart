import 'package:steelforce/core/database/drift/daos/workflow_state_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/my_visits/data/models/active_workflow_model.dart';

abstract interface class WorkflowStateLocalDataSource {
  Future<ActiveWorkflowModel?> getActiveWorkflow();
  Future<void> saveActiveWorkflow(ActiveWorkflowModel workflow);
  Future<void> clearActiveWorkflow();
}

/// Drift-backed resume pointer (**T1.5b**), replacing the plaintext `routes.db`
/// implementation. With this cutover the legacy file has no readers left.
///
/// `ActiveWorkflowModel.fromRow`/`toRow` still own the mapping in both
/// directions, unchanged — see the note on the `WorkflowState` table about why
/// this is a move rather than ADR-007's generalization.
class WorkflowStateLocalDataSourceImpl implements WorkflowStateLocalDataSource {
  const WorkflowStateLocalDataSourceImpl(this._dao);
  final WorkflowStateDao _dao;

  @override
  Future<ActiveWorkflowModel?> getActiveWorkflow() async {
    try {
      final row = await _dao.getActive();
      return row == null ? null : ActiveWorkflowModel.fromRow(row);
    } catch (e) {
      throw CacheException(message: 'Failed to load active workflow: $e');
    }
  }

  @override
  Future<void> saveActiveWorkflow(ActiveWorkflowModel workflow) async {
    try {
      await _dao.saveActive(workflow.toRow());
    } catch (e) {
      throw CacheException(message: 'Failed to save active workflow: $e');
    }
  }

  @override
  Future<void> clearActiveWorkflow() async {
    try {
      await _dao.clearActive();
    } catch (e) {
      throw CacheException(message: 'Failed to clear active workflow: $e');
    }
  }
}
