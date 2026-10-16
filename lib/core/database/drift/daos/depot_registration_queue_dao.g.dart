// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'depot_registration_queue_dao.dart';

// ignore_for_file: type=lint
mixin _$DepotRegistrationQueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $DepotRegistrationQueueTable get depotRegistrationQueue =>
      attachedDatabase.depotRegistrationQueue;
  DepotRegistrationQueueDaoManager get managers =>
      DepotRegistrationQueueDaoManager(this);
}

class DepotRegistrationQueueDaoManager {
  final _$DepotRegistrationQueueDaoMixin _db;
  DepotRegistrationQueueDaoManager(this._db);
  $$DepotRegistrationQueueTableTableManager get depotRegistrationQueue =>
      $$DepotRegistrationQueueTableTableManager(
          _db.attachedDatabase, _db.depotRegistrationQueue);
}
