// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_dao.dart';

// ignore_for_file: type=lint
mixin _$QuotationDaoMixin on DatabaseAccessor<AppDatabase> {
  $QuotationsTable get quotations => attachedDatabase.quotations;
  QuotationDaoManager get managers => QuotationDaoManager(this);
}

class QuotationDaoManager {
  final _$QuotationDaoMixin _db;
  QuotationDaoManager(this._db);
  $$QuotationsTableTableManager get quotations =>
      $$QuotationsTableTableManager(_db.attachedDatabase, _db.quotations);
}

mixin _$SalesOrderDaoMixin on DatabaseAccessor<AppDatabase> {
  $SalesOrdersTable get salesOrders => attachedDatabase.salesOrders;
  SalesOrderDaoManager get managers => SalesOrderDaoManager(this);
}

class SalesOrderDaoManager {
  final _$SalesOrderDaoMixin _db;
  SalesOrderDaoManager(this._db);
  $$SalesOrdersTableTableManager get salesOrders =>
      $$SalesOrdersTableTableManager(_db.attachedDatabase, _db.salesOrders);
}

mixin _$SyncQueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  $QuotationsTable get quotations => attachedDatabase.quotations;
  SyncQueueDaoManager get managers => SyncQueueDaoManager(this);
}

class SyncQueueDaoManager {
  final _$SyncQueueDaoMixin _db;
  SyncQueueDaoManager(this._db);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
  $$QuotationsTableTableManager get quotations =>
      $$QuotationsTableTableManager(_db.attachedDatabase, _db.quotations);
}
