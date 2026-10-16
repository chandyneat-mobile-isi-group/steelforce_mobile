// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_dao.dart';

// ignore_for_file: type=lint
mixin _$GeoDaoMixin on DatabaseAccessor<AppDatabase> {
  $GeoProvincesTable get geoProvinces => attachedDatabase.geoProvinces;
  $GeoDistrictsTable get geoDistricts => attachedDatabase.geoDistricts;
  $GeoCommunesTable get geoCommunes => attachedDatabase.geoCommunes;
  $GeoVillagesTable get geoVillages => attachedDatabase.geoVillages;
  GeoDaoManager get managers => GeoDaoManager(this);
}

class GeoDaoManager {
  final _$GeoDaoMixin _db;
  GeoDaoManager(this._db);
  $$GeoProvincesTableTableManager get geoProvinces =>
      $$GeoProvincesTableTableManager(_db.attachedDatabase, _db.geoProvinces);
  $$GeoDistrictsTableTableManager get geoDistricts =>
      $$GeoDistrictsTableTableManager(_db.attachedDatabase, _db.geoDistricts);
  $$GeoCommunesTableTableManager get geoCommunes =>
      $$GeoCommunesTableTableManager(_db.attachedDatabase, _db.geoCommunes);
  $$GeoVillagesTableTableManager get geoVillages =>
      $$GeoVillagesTableTableManager(_db.attachedDatabase, _db.geoVillages);
}
