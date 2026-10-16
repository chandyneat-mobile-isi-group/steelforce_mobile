// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_dao.dart';

// ignore_for_file: type=lint
mixin _$NotificationDaoMixin on DatabaseAccessor<AppDatabase> {
  $NotificationsTable get notifications => attachedDatabase.notifications;
  $NotificationActionQueueTable get notificationActionQueue =>
      attachedDatabase.notificationActionQueue;
  $NotificationSyncMetaTable get notificationSyncMeta =>
      attachedDatabase.notificationSyncMeta;
  NotificationDaoManager get managers => NotificationDaoManager(this);
}

class NotificationDaoManager {
  final _$NotificationDaoMixin _db;
  NotificationDaoManager(this._db);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db.attachedDatabase, _db.notifications);
  $$NotificationActionQueueTableTableManager get notificationActionQueue =>
      $$NotificationActionQueueTableTableManager(
          _db.attachedDatabase, _db.notificationActionQueue);
  $$NotificationSyncMetaTableTableManager get notificationSyncMeta =>
      $$NotificationSyncMetaTableTableManager(
          _db.attachedDatabase, _db.notificationSyncMeta);
}
