import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/geo_dao.dart';

/// DAO-level tests against a real (in-memory) SQLite database, per the T2 test
/// matrix. The fixture is a hand-built slice of the real gazetteer rather than
/// the 1.3 MB asset — these tests are about the queries, and a 16,000-row
/// import per test would make them slow without testing anything more.
/// `geo_seed_import_test.dart` covers the real asset.

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

// Phnom Penh (12) with two khans, and Kandal (08) with one district — enough
// for "only this parent's children" to mean something.
final _provinces = [
  GeoProvincesCompanion.insert(
      code: '12', nameEn: 'Phnom Penh', nameKm: 'ភ្នំពេញ', unit: 'Capital'),
  GeoProvincesCompanion.insert(
      code: '08', nameEn: 'Kandal', nameKm: 'កណ្ដាល', unit: 'Province'),
];

final _districts = [
  GeoDistrictsCompanion.insert(
      code: '1201',
      provinceCode: '12',
      nameEn: 'Chamkar Mon',
      nameKm: 'ចំការមន',
      unit: 'Khan'),
  GeoDistrictsCompanion.insert(
      code: '1202',
      provinceCode: '12',
      nameEn: 'Doun Penh',
      nameKm: 'ដូនពេញ',
      unit: 'Khan'),
  GeoDistrictsCompanion.insert(
      code: '0801',
      provinceCode: '08',
      nameEn: 'Kandal Stueng',
      nameKm: 'កណ្ដាលស្ទឹង',
      unit: 'District'),
];

final _communes = [
  GeoCommunesCompanion.insert(
      code: '120101',
      districtCode: '1201',
      provinceCode: '12',
      nameEn: 'Tonle Basak',
      nameKm: 'ទន្លេបាសាក់',
      unit: 'Sangkat',
      postalCode: const Value('120101')),
  GeoCommunesCompanion.insert(
      code: '120102',
      districtCode: '1201',
      provinceCode: '12',
      nameEn: 'Boeng Keng Kang 1',
      nameKm: 'បឹងកេងកងទី ១',
      unit: 'Sangkat',
      postalCode: const Value('120102')),
  // A commune the postal source does not cover — the null case.
  GeoCommunesCompanion.insert(
      code: '080101',
      districtCode: '0801',
      provinceCode: '08',
      nameEn: 'Ampov Prey',
      nameKm: 'អំពៅព្រៃ',
      unit: 'Commune'),
];

final _villages = [
  GeoVillagesCompanion.insert(
      code: '12010101',
      communeCode: '120101',
      nameEn: 'Ou Thum',
      nameKm: 'អូរធំ'),
  GeoVillagesCompanion.insert(
      code: '12010102',
      communeCode: '120101',
      nameEn: 'Prek Thmei',
      nameKm: 'ព្រែកថ្មី'),
  GeoVillagesCompanion.insert(
      code: '12010201',
      communeCode: '120102',
      nameEn: 'Village 1',
      nameKm: 'ភូមិ ១'),
];

Future<void> _seed(GeoDao dao) => dao.replaceAll(
      provinces: _provinces,
      districts: _districts,
      communes: _communes,
      villages: _villages,
    );

void main() {
  late AppDatabase db;
  late GeoDao dao;

  setUp(() async {
    db = _memoryDb();
    dao = db.geoDao;
    await _seed(dao);
  });

  tearDown(() => db.close());

  group('cascading reads', () {
    test('districts are scoped to their province', () async {
      final pp = await dao.districtsOf('12');
      expect(pp.map((d) => d.code), ['1201', '1202']);

      final kandal = await dao.districtsOf('08');
      expect(kandal.map((d) => d.code), ['0801']);
    });

    test('communes are scoped to their district', () async {
      expect((await dao.communesOf('1201')).map((c) => c.code),
          ['120101', '120102']);
      expect((await dao.communesOf('0801')).map((c) => c.code), ['080101']);
    });

    test('villages are scoped to their commune', () async {
      expect((await dao.villagesOf('120101')).map((v) => v.code),
          ['12010101', '12010102']);
      expect((await dao.villagesOf('120102')).length, 1);
    });

    test('an unknown parent yields an empty list, not every row', () async {
      expect(await dao.districtsOf('99'), isEmpty);
      expect(await dao.villagesOf('999999'), isEmpty);
    });

    test('provinces come back in code order, not name order', () async {
      expect((await dao.allProvinces()).map((p) => p.code), ['08', '12']);
    });
  });

  group('search (§7)', () {
    test('finds a province by its English name, case-insensitively', () async {
      expect((await dao.searchProvinces('phnom')).single.code, '12');
      expect((await dao.searchProvinces('PHNOM')).single.code, '12');
    });

    test('finds a province by its Khmer name', () async {
      expect((await dao.searchProvinces('ភ្នំពេញ')).single.code, '12');
    });

    test('finds a province by code', () async {
      expect((await dao.searchProvinces('08')).single.nameEn, 'Kandal');
    });

    test('finds a commune by postal code', () async {
      final hits = await dao.searchCommunes('120102');
      expect(hits.single.nameEn, 'Boeng Keng Kang 1');
    });

    test('village search stays inside its commune', () async {
      // 'Village 1' lives in 120102, so searching 120101 must not return it
      // even though the text matches.
      expect(await dao.searchVillagesIn('120101', 'Village 1'), isEmpty);
      expect((await dao.searchVillagesIn('120102', 'Village')).single.code,
          '12010201');
    });

    test('a commune search is capped', () async {
      // Matches everything; the cap is what stops a one-character query from
      // returning the whole table.
      final hits = await dao.searchCommunes('0', limit: 2);
      expect(hits.length, lessThanOrEqualTo(2));
    });

    test('no match returns empty rather than everything', () async {
      expect(await dao.searchProvinces('zzzz'), isEmpty);
    });
  });

  group('postal code', () {
    test('is returned where the gazetteer has one', () async {
      expect((await dao.commune('120101'))!.postalCode, '120101');
    });

    test('is null — not blank or guessed — where it has none', () async {
      expect((await dao.commune('080101'))!.postalCode, isNull);
    });
  });

  group('replaceAll', () {
    test('is atomic and idempotent', () async {
      await _seed(dao);
      expect(await dao.provinceCount(), 2);
      expect((await dao.villagesOf('120101')).length, 2,
          reason: 're-seeding must replace, not duplicate');
    });

    test('a re-seed removes rows that are gone from the new gazetteer',
        () async {
      await dao.replaceAll(
        provinces: [_provinces.first],
        districts: const [],
        communes: const [],
        villages: const [],
      );
      expect(await dao.provinceCount(), 1);
      expect(await dao.districtsOf('12'), isEmpty);
      expect(await dao.villagesOf('120101'), isEmpty);
    });
  });

  group('single-row lookups', () {
    test('resolve a known code and return null for an unknown one', () async {
      expect((await dao.province('12'))!.nameEn, 'Phnom Penh');
      expect(await dao.province('99'), isNull);
      expect((await dao.village('12010101'))!.nameEn, 'Ou Thum');
      expect(await dao.village('99999999'), isNull);
    });
  });
}
