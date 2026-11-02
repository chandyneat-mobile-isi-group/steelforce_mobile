// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit_plan_dao.dart';

// ignore_for_file: type=lint
mixin _$VisitPlanDaoMixin on DatabaseAccessor<AppDatabase> {
  $VisitPlanSnapshotsTable get visitPlanSnapshots =>
      attachedDatabase.visitPlanSnapshots;
  $PlanVisitOutboxTable get planVisitOutbox => attachedDatabase.planVisitOutbox;
  VisitPlanDaoManager get managers => VisitPlanDaoManager(this);
}

class VisitPlanDaoManager {
  final _$VisitPlanDaoMixin _db;
  VisitPlanDaoManager(this._db);
  $$VisitPlanSnapshotsTableTableManager get visitPlanSnapshots =>
      $$VisitPlanSnapshotsTableTableManager(
          _db.attachedDatabase, _db.visitPlanSnapshots);
  $$PlanVisitOutboxTableTableManager get planVisitOutbox =>
      $$PlanVisitOutboxTableTableManager(
          _db.attachedDatabase, _db.planVisitOutbox);
}
