import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/geo_location/data/datasources/geo_local_data_source.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/domain/repositories/geo_location_repository.dart';

/// Local-only implementation over the bundled gazetteer.
///
/// There is no remote branch and no connectivity check, because there is no
/// geographic endpoint — see the note on [GeoLocationRepository]. Every read
/// resolves from the encrypted Drift tables, so the selector behaves
/// identically on a handset that has been offline for a week.
class GeoLocationRepositoryImpl implements GeoLocationRepository {
  GeoLocationRepositoryImpl(this._local, this._logger);

  final GeoLocalDataSource _local;
  final AppLogger _logger;

  /// In-memory cache of the levels already read this session (§5).
  ///
  /// Keyed by `level:parentCode`. The Drift reads it saves are already fast —
  /// indexed lookups over at most 33 rows — but a rep correcting a typo walks
  /// back up and down the cascade repeatedly, and re-querying on every step
  /// makes the picker flash a loading state for data that has not changed.
  ///
  /// Unbounded on purpose: the worst case is one entry per level the rep
  /// actually visits in one form, which is single digits. It is an instance
  /// field, not a static, so it dies with the repository rather than outliving
  /// a re-seed.
  final Map<String, List<GeoUnit>> _cache = {};

  /// Clears the level cache. Called by [ensureSeeded] after an import, so a
  /// re-seed cannot serve rows the database no longer has.
  void invalidateCache() => _cache.clear();

  @override
  ResultFuture<void> ensureSeeded() async {
    try {
      await _local.seedIfEmpty();
      invalidateCache();
      return const Success(null);
    } on CacheException catch (e) {
      _logger.error('geo.seed_failed', error: e);
      return Failed(CacheFailure(message: e.message));
    } catch (e, s) {
      _logger.error('geo.seed_failed', error: e, stackTrace: s);
      return const Failed(
        CacheFailure(message: 'Unable to prepare location data.'),
      );
    }
  }

  @override
  ResultFuture<List<GeoUnit>> childrenOf(
    GeoLevel level,
    String? parentCode,
  ) async {
    final key = '${level.name}:${parentCode ?? ''}';
    final cached = _cache[key];
    if (cached != null) return Success(cached);

    try {
      final units = await _local.childrenOf(level, parentCode);
      _cache[key] = units;
      return Success(units);
    } catch (e, s) {
      _logger.error(
        'geo.children_read_failed',
        error: e,
        stackTrace: s,
        fields: {'key': key},
      );
      return const Failed(
        CacheFailure(message: 'Unable to load location data.'),
      );
    }
  }

  @override
  ResultFuture<List<GeoUnit>> search(
    GeoLevel level,
    String? parentCode,
    String query,
  ) async {
    // An empty query is the unfiltered list, which is the cached path — so
    // clearing the search box costs nothing.
    if (query.trim().isEmpty) return childrenOf(level, parentCode);
    try {
      return Success(await _local.search(level, parentCode, query));
    } catch (e, s) {
      _logger.error('geo.search_failed', error: e, stackTrace: s);
      return const Failed(
        CacheFailure(message: 'Unable to search location data.'),
      );
    }
  }

  @override
  ResultFuture<GeoAddress> resolveAddress({
    String? provinceCode,
    String? districtCode,
    String? communeCode,
    String? villageCode,
    String? postalCode,
  }) async {
    try {
      // Resolved parent-first, and stopped at the first level that is absent or
      // does not belong to the level above it. Returning a partially resolved
      // address is the right answer: the rep sees their province still selected
      // and re-picks one district, instead of an empty form or — worse — a
      // village silently attached to the wrong commune.
      final province = provinceCode == null
          ? null
          : await _local.unit(GeoLevel.province, provinceCode);
      if (province == null) return const Success(GeoAddress.empty);

      final district = districtCode == null
          ? null
          : await _local.unit(GeoLevel.district, districtCode);
      if (district == null || !district.isChildOf(province.code)) {
        _logIfBroken(district != null, 'district', districtCode, provinceCode);
        return Success(GeoAddress(province: province));
      }

      final commune = communeCode != null
          ? await _local.unit(GeoLevel.commune, communeCode)
          : (postalCode != null
              ? await _local.communeByPostalCode(postalCode)
              : null);
      if (commune == null || !commune.isChildOf(district.code)) {
        _logIfBroken(commune != null, 'commune', communeCode ?? commune?.code,
            districtCode);
        return Success(GeoAddress(province: province, district: district));
      }

      final village = villageCode == null
          ? null
          : await _local.unit(GeoLevel.village, villageCode);
      final villageBelongs = village != null && village.isChildOf(commune.code);
      if (village != null && !villageBelongs) {
        _logIfBroken(true, 'village', villageCode, communeCode);
      }

      return Success(
        GeoAddress(
          province: province,
          district: district,
          commune: commune,
          village: villageBelongs ? village : null,
          // The stored code is a fallback only. If the gazetteer has a code for
          // this commune it wins, because a code stored months ago may predate
          // a postal reassignment — and `GeoAddress.postalCode` prefers the
          // commune's anyway, so passing it here is harmless when both exist.
          manualPostalCode: postalCode,
        ),
      );
    } catch (e, s) {
      _logger.error('geo.resolve_failed', error: e, stackTrace: s);
      return const Failed(
        CacheFailure(message: 'Unable to resolve the saved location.'),
      );
    }
  }

  /// A code that resolves to a real row but hangs off the wrong parent means
  /// bad stored data, not a missing row — worth a log line, because it points
  /// at whatever wrote it. Codes only; no names, so nothing here is PII
  /// (`docs/skills/security.md` §10).
  void _logIfBroken(bool resolved, String level, String? code, String? parent) {
    if (!resolved) return;
    _logger.warning(
      'geo.hierarchy_broken',
      fields: {'level': level, 'code': code, 'expectedParent': parent},
    );
  }
}
