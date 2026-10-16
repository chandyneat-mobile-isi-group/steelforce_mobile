import 'package:steelforce/core/database/drift/daos/geo_dao.dart';
import 'package:steelforce/features/geo_location/data/datasources/geo_seed_asset_loader.dart';
import 'package:steelforce/features/geo_location/data/mappers/geo_drift_mappers.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';

/// Local reads of the gazetteer, in domain terms.
///
/// A thin interface over [GeoDao] rather than the DAO itself, so the repository
/// can be tested against a fake without standing up an encrypted database, and
/// so the level-dispatch (`switch (level)`) lives in one place instead of in
/// every caller.
abstract class GeoLocalDataSource {
  Future<void> seedIfEmpty();
  Future<List<GeoUnit>> childrenOf(GeoLevel level, String? parentCode);
  Future<List<GeoUnit>> search(
    GeoLevel level,
    String? parentCode,
    String query,
  );
  Future<GeoUnit?> unit(GeoLevel level, String code);

  /// The commune carrying exactly [postalCode], or null. See
  /// [GeoDao.communeByPostalCode] for why this is a sound reverse lookup.
  Future<GeoUnit?> communeByPostalCode(String postalCode);
}

class GeoDriftLocalDataSource implements GeoLocalDataSource {
  const GeoDriftLocalDataSource(this._dao, this._seedLoader);

  final GeoDao _dao;
  final GeoSeedAssetLoader _seedLoader;

  @override
  Future<void> seedIfEmpty() async {
    // Presence of provinces is the readiness flag. `replaceAll` is one
    // transaction, so a non-zero count means all four levels landed — there is
    // no state where provinces exist and villages do not.
    if (await _dao.provinceCount() > 0) return;
    final seed = await _seedLoader.load();
    await _dao.replaceAll(
      provinces: seed.provinces,
      districts: seed.districts,
      communes: seed.communes,
      villages: seed.villages,
    );
  }

  @override
  Future<List<GeoUnit>> childrenOf(GeoLevel level, String? parentCode) async {
    switch (level) {
      case GeoLevel.province:
        return (await _dao.allProvinces()).map((r) => r.toEntity()).toList();
      case GeoLevel.district:
        return (await _dao.districtsOf(_require(level, parentCode)))
            .map((r) => r.toEntity())
            .toList();
      case GeoLevel.commune:
        return (await _dao.communesOf(_require(level, parentCode)))
            .map((r) => r.toEntity())
            .toList();
      case GeoLevel.village:
        return (await _dao.villagesOf(_require(level, parentCode)))
            .map((r) => r.toEntity())
            .toList();
    }
  }

  @override
  Future<List<GeoUnit>> search(
    GeoLevel level,
    String? parentCode,
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return childrenOf(level, parentCode);

    switch (level) {
      case GeoLevel.province:
        return (await _dao.searchProvinces(trimmed))
            .map((r) => r.toEntity())
            .toList();
      case GeoLevel.village:
        return (await _dao.searchVillagesIn(
                _require(level, parentCode), trimmed))
            .map((r) => r.toEntity())
            .toList();
      case GeoLevel.district:
      case GeoLevel.commune:
        // Districts and communes are filtered in memory against the parent's
        // list — at most 18 communes in a district and 14 districts in a khan,
        // so a SQL round trip per keystroke would cost more than it saves. The
        // village and province cases go to SQL because their lists are not
        // bounded the same way (province search spans all 25 with no parent to
        // narrow by, and a commune's villages are fetched by an indexed scan
        // that is already written).
        final all = await childrenOf(level, parentCode);
        final needle = trimmed.toLowerCase();
        return all.where((u) {
          return u.name.en.toLowerCase().contains(needle) ||
              u.name.km.contains(trimmed) ||
              u.code.contains(trimmed) ||
              (u.postalCode?.contains(trimmed) ?? false);
        }).toList();
    }
  }

  @override
  Future<GeoUnit?> unit(GeoLevel level, String code) async {
    return switch (level) {
      GeoLevel.province => (await _dao.province(code))?.toEntity(),
      GeoLevel.district => (await _dao.district(code))?.toEntity(),
      GeoLevel.commune => (await _dao.commune(code))?.toEntity(),
      GeoLevel.village => (await _dao.village(code))?.toEntity(),
    };
  }

  @override
  Future<GeoUnit?> communeByPostalCode(String postalCode) async =>
      (await _dao.communeByPostalCode(postalCode))?.toEntity();

  /// A null parent below the province level is a caller bug, not a user
  /// condition — the UI disables a level until its parent is chosen. Failing
  /// loudly here is what stops it from silently reading the whole table.
  String _require(GeoLevel level, String? parentCode) {
    if (parentCode == null || parentCode.isEmpty) {
      throw ArgumentError.notNull('parentCode for ${level.name}');
    }
    return parentCode;
  }
}
