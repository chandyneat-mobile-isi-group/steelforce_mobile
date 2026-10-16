// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_state_dao.dart';

// ignore_for_file: type=lint
mixin _$WorkflowStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkflowStateTable get workflowState => attachedDatabase.workflowState;
  WorkflowStateDaoManager get managers => WorkflowStateDaoManager(this);
}

class WorkflowStateDaoManager {
  final _$WorkflowStateDaoMixin _db;
  WorkflowStateDaoManager(this._db);
  $$WorkflowStateTableTableManager get workflowState =>
      $$WorkflowStateTableTableManager(_db.attachedDatabase, _db.workflowState);
}
