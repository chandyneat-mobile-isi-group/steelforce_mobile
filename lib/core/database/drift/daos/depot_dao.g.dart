// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'depot_dao.dart';

// ignore_for_file: type=lint
mixin _$DepotDaoMixin on DatabaseAccessor<AppDatabase> {
  $DepotsTable get depots => attachedDatabase.depots;
  $DepotContactsTable get depotContacts => attachedDatabase.depotContacts;
  $DepotNotesTable get depotNotes => attachedDatabase.depotNotes;
  $DepotActivitiesTable get depotActivities => attachedDatabase.depotActivities;
  $DepotFavoritesTable get depotFavorites => attachedDatabase.depotFavorites;
  $DepotRecentTable get depotRecent => attachedDatabase.depotRecent;
  $DepotSyncMetaTable get depotSyncMeta => attachedDatabase.depotSyncMeta;
  DepotDaoManager get managers => DepotDaoManager(this);
}

class DepotDaoManager {
  final _$DepotDaoMixin _db;
  DepotDaoManager(this._db);
  $$DepotsTableTableManager get depots =>
      $$DepotsTableTableManager(_db.attachedDatabase, _db.depots);
  $$DepotContactsTableTableManager get depotContacts =>
      $$DepotContactsTableTableManager(_db.attachedDatabase, _db.depotContacts);
  $$DepotNotesTableTableManager get depotNotes =>
      $$DepotNotesTableTableManager(_db.attachedDatabase, _db.depotNotes);
  $$DepotActivitiesTableTableManager get depotActivities =>
      $$DepotActivitiesTableTableManager(
          _db.attachedDatabase, _db.depotActivities);
  $$DepotFavoritesTableTableManager get depotFavorites =>
      $$DepotFavoritesTableTableManager(
          _db.attachedDatabase, _db.depotFavorites);
  $$DepotRecentTableTableManager get depotRecent =>
      $$DepotRecentTableTableManager(_db.attachedDatabase, _db.depotRecent);
  $$DepotSyncMetaTableTableManager get depotSyncMeta =>
      $$DepotSyncMetaTableTableManager(_db.attachedDatabase, _db.depotSyncMeta);
}
