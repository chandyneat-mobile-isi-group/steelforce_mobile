import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/geo_location/data/datasources/geo_local_data_source.dart';
import 'package:steelforce/features/geo_location/data/repositories/geo_location_repository_impl.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';

/// The repository is where codes from outside the cascade — a server draft, a
/// Drift row, a deep link — are turned back into an address. That is the only
/// path a broken hierarchy can take into the app, so it is the path tested
/// hardest here (§14).

GeoUnit _u(GeoLevel level, String code, String en, {String? postal}) => GeoUnit(
      level: level,
      code: code,
      name: LocalizedText(en: en, km: en),
      unit: 'Unit',
      postalCode: postal,
    );

/// A hand-built gazetteer: Phnom Penh (12) → Chamkar Mon (1201) → Tonle Basak
/// (120101) → Ou Thum (12010101), plus Kandal (08) → Kandal Stueng (0801).
class _FakeSource implements GeoLocalDataSource {
  _FakeSource({this.throwOnRead = false});

  final bool throwOnRead;
  int seedCalls = 0;
  int readCalls = 0;

  final _units = <String, GeoUnit>{
    '12': _u(GeoLevel.province, '12', 'Phnom Penh'),
    '08': _u(GeoLevel.province, '08', 'Kandal'),
    '1201': _u(GeoLevel.district, '1201', 'Chamkar Mon'),
    '0801': _u(GeoLevel.district, '0801', 'Kandal Stueng'),
    '120101': _u(GeoLevel.commune, '120101', 'Tonle Basak', postal: '120101'),
    '120199': _u(GeoLevel.commune, '120199', 'Uncovered'),
    '12010101': _u(GeoLevel.village, '12010101', 'Ou Thum'),
    '08010101': _u(GeoLevel.village, '08010101', 'Elsewhere'),
  };

  @override
  Future<void> seedIfEmpty() async {
    seedCalls++;
  }

  @override
  Future<GeoUnit?> unit(GeoLevel level, String code) async {
    if (throwOnRead) throw const CacheException(message: 'db gone');
    final u = _units[code];
    return (u != null && u.level == level) ? u : null;
  }

  @override
  Future<List<GeoUnit>> childrenOf(GeoLevel level, String? parentCode) async {
    if (throwOnRead) throw const CacheException(message: 'db gone');
    readCalls++;
    return _units.values
        .where((u) =>
            u.level == level &&
            (parentCode == null || u.code.startsWith(parentCode)))
        .toList();
  }

  @override
  Future<List<GeoUnit>> search(
    GeoLevel level,
    String? parentCode,
    String query,
  ) async {
    if (throwOnRead) throw const CacheException(message: 'db gone');
    final all = await childrenOf(level, parentCode);
    return all
        .where((u) => u.name.en.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<GeoUnit?> communeByPostalCode(String postalCode) async {
    if (throwOnRead) throw const CacheException(message: 'db gone');
    for (final u in _units.values) {
      if (u.level == GeoLevel.commune && u.postalCode == postalCode) return u;
    }
    return null;
  }
}

GeoLocationRepositoryImpl _repo(_FakeSource source) =>
    GeoLocationRepositoryImpl(source, const ConsoleAppLogger());

void main() {
  group('resolveAddress — hierarchy enforcement (§14)', () {
    test('resolves a fully consistent set of codes', () async {
      final result = await _repo(_FakeSource()).resolveAddress(
        provinceCode: '12',
        districtCode: '1201',
        communeCode: '120101',
        villageCode: '12010101',
      );

      final address = (result as Success).data;
      expect(address.province?.code, '12');
      expect(address.district?.code, '1201');
      expect(address.commune?.code, '120101');
      expect(address.village?.code, '12010101');
      expect(address.postalCode, '120101');
      expect(address.isHierarchyIntact, isTrue);
    });

    test(
        'drops a district that belongs to another province, and everything '
        'under it', () async {
      final result = await _repo(_FakeSource()).resolveAddress(
        provinceCode: '12',
        districtCode: '0801', // Kandal's district under Phnom Penh
        communeCode: '120101',
        villageCode: '12010101',
      );

      final address = (result as Success).data;
      expect(address.province?.code, '12');
      expect(address.district, isNull);
      expect(address.commune, isNull, reason: 'orphaned by the dropped parent');
      expect(address.village, isNull);
      expect(address.isHierarchyIntact, isTrue,
          reason: 'what survives must still be internally consistent');
    });

    test('drops a village that belongs to another commune but keeps the rest',
        () async {
      final result = await _repo(_FakeSource()).resolveAddress(
        provinceCode: '12',
        districtCode: '1201',
        communeCode: '120101',
        villageCode: '08010101', // not under 120101
      );

      final address = (result as Success).data;
      expect(address.commune?.code, '120101');
      expect(address.village, isNull);
      expect(address.isHierarchyIntact, isTrue);
    });

    test('an unknown province yields an empty address', () async {
      final result =
          await _repo(_FakeSource()).resolveAddress(provinceCode: '99');
      expect((result as Success).data.province, isNull);
    });

    test('a partial set resolves as far as it goes', () async {
      final result = await _repo(_FakeSource())
          .resolveAddress(provinceCode: '12', districtCode: '1201');

      final address = (result as Success).data;
      expect(address.district?.code, '1201');
      expect(address.commune, isNull);
    });

    test('the gazetteer postal code beats a stored one', () async {
      final result = await _repo(_FakeSource()).resolveAddress(
        provinceCode: '12',
        districtCode: '1201',
        communeCode: '120101',
        postalCode: '99999',
      );
      expect((result as Success).data.postalCode, '120101');
    });

    test('a stored postal code is kept when the commune has none', () async {
      final result = await _repo(_FakeSource()).resolveAddress(
        provinceCode: '12',
        districtCode: '1201',
        communeCode: '120199',
        postalCode: '120199',
      );
      final address = (result as Success).data;
      expect(address.postalCode, '120199');
      expect(address.isPostalCodeDerived, isFalse);
    });

    test('reverse-resolves commune by postal code when communeCode is omitted',
        () async {
      final result = await _repo(_FakeSource()).resolveAddress(
        provinceCode: '12',
        districtCode: '1201',
        postalCode: '120101',
      );
      final address = (result as Success).data;
      expect(address.commune?.code, '120101');
      expect(address.postalCode, '120101');
      expect(address.isHierarchyIntact, isTrue);
    });
  });

  group('caching (§5)', () {
    test('a repeated read of the same level does not hit the source twice',
        () async {
      final source = _FakeSource();
      final repo = _repo(source);

      await repo.childrenOf(GeoLevel.province, null);
      await repo.childrenOf(GeoLevel.province, null);
      expect(source.readCalls, 1);
    });

    test('different parents are cached separately', () async {
      final source = _FakeSource();
      final repo = _repo(source);

      await repo.childrenOf(GeoLevel.district, '12');
      await repo.childrenOf(GeoLevel.district, '08');
      expect(source.readCalls, 2);
    });

    test('an empty search falls back to the cached unfiltered list', () async {
      final source = _FakeSource();
      final repo = _repo(source);

      await repo.childrenOf(GeoLevel.province, null);
      await repo.search(GeoLevel.province, null, '   ');
      expect(source.readCalls, 1);
    });

    test(
        'seeding invalidates the cache so a re-seed is never served stale '
        'rows', () async {
      final source = _FakeSource();
      final repo = _repo(source);

      await repo.childrenOf(GeoLevel.province, null);
      await repo.ensureSeeded();
      await repo.childrenOf(GeoLevel.province, null);
      expect(source.readCalls, 2);
    });
  });

  group('failures', () {
    test('a read error becomes a CacheFailure, not an exception', () async {
      final result = await _repo(_FakeSource(throwOnRead: true))
          .childrenOf(GeoLevel.province, null);
      expect(result, isA<Failed<List<GeoUnit>>>());
      expect((result as Failed).failure, isA<CacheFailure>());
    });

    test('a resolve error becomes a CacheFailure', () async {
      final result = await _repo(_FakeSource(throwOnRead: true))
          .resolveAddress(provinceCode: '12');
      expect(result, isA<Failed>());
    });

    test('ensureSeeded reports success when the source seeds cleanly',
        () async {
      final source = _FakeSource();
      final result = await _repo(source).ensureSeeded();
      expect(result, isA<Success<void>>());
      expect(source.seedCalls, 1);
    });
  });
}
