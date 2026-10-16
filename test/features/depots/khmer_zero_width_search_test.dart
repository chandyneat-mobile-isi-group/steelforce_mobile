import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/utils/text_normalization.dart';

/// Khmer depot search must survive SAP's zero-width word-break hints.
///
/// SAP embeds `U+200B/200C/200D` inside Khmer names — 1,130 of 5,990 names in
/// the current extract. They are invisible, so a representative reads a shop's
/// name off the list, types it back, and a naive `LIKE` returns nothing. The
/// server strips them from both sides before comparing; local search has to
/// agree, or the offline directory answers differently from the online one.
///
/// See `docs/feature/depot/mobile/search-depot.md` §Khmer search, whose
/// verified example — `រស្មី សៀមរាប` matching a name stored with three
/// zero-width spaces — is the first test below.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// `ដេប៉ូ` + three ZWSPs + ` រស្មី សៀមរាប`, exactly as the ERP stores it.
  const storedName = 'ដេប៉ូ​​​ រស្មី សៀមរាប';

  /// What the rep can actually type, having read it off the screen.
  const typedName = 'ដេប៉ូ រស្មី សៀមរាប';

  Future<void> seed({
    required String id,
    required String shopName,
    String? khName,
    String phone = '023456005',
  }) =>
      db.customStatement(
        'INSERT INTO depots (id, depot_code, shop_name, owner_name, '
        'phone, address, province, district, territory, latitude, longitude, '
        'credit_limit, status, assigned_rep_id, assigned_rep_name, updated_at, '
        'kh_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id, 'C-$id', shopName, 'Heng Vuthy', phone, 'St 271', 'PP', 'TK',
          'PP-NORTH', 11.5, 104.9, 0, 'Active', 'rep-1', 'Rep One',
          // DateTime columns are ISO-8601 UTC *text* in this schema
          // (`build.yaml`), not unix seconds.
          '2026-08-28T00:00:00.000Z',
          khName,
        ],
      );

  Future<List<String>> search(String query) async {
    final rows = await db.depotDao.browse(page: 0, pageSize: 50, query: query);
    return rows.map((c) => c.id).toList();
  }

  group('stripZeroWidth', () {
    test('removes all three characters SAP uses', () {
      expect(stripZeroWidth(storedName), typedName);
    });

    test('leaves ordinary text untouched', () {
      expect(stripZeroWidth('Toul Kork Depot'), 'Toul Kork Depot');
      expect(stripZeroWidth(''), '');
    });
  });

  group('normalizeSearchTerm', () {
    test('reduces phone-shaped input to digits', () {
      // Phones are normalised on write, so `012 345 678` is stored as
      // `012345678` -- searching with the spaces would match nothing.
      expect(normalizeSearchTerm('012 345 678'), '012345678');
      expect(normalizeSearchTerm('+855-12-345-678'), '+85512345678');
    });

    test('leaves Khmer and Latin text otherwise verbatim', () {
      expect(normalizeSearchTerm('  ដេប៉ូ  '), 'ដេប៉ូ');
      expect(normalizeSearchTerm('Toul Kork'), 'Toul Kork');
    });

    test('a short numeric code is not mistaken for a phone number', () {
      // Five characters, below the phone threshold: the dash must survive,
      // because it is part of the code the rep is looking for.
      expect(normalizeSearchTerm('61-00'), '61-00');
    });
  });

  group('searching the directory', () {
    test('a name typed without the hidden characters still finds the shop',
        () async {
      await seed(id: 'c1', shopName: storedName);

      expect(await search(typedName), ['c1'],
          reason: 'this is the exact case the docs record as verified '
              'server-side; local search must agree');
    });

    test('a partial Khmer term matches across a stored zero-width space',
        () async {
      await seed(id: 'c1', shopName: 'ដេប៉ូ​ តាំង');

      expect(await search('ដេប៉ូ តាំង'), ['c1']);
    });

    test('the term is stripped too, so pasting the stored name still works',
        () async {
      await seed(id: 'c1', shopName: storedName);

      // A rep who copies the name out of another screen carries the hidden
      // characters with it. Both sides are stripped, so it matches either way.
      expect(await search(storedName), ['c1']);
    });

    test('kh_name is searched with the same normalisation', () async {
      await seed(id: 'c1', shopName: 'PNP-DEPOT REAKSMEY', khName: storedName);

      expect(await search(typedName), ['c1']);
    });

    test('a phone typed with spaces matches the stored digits', () async {
      await seed(id: 'c1', shopName: 'Toul Kork Depot', phone: '012345678');

      expect(await search('012 345 678'), ['c1']);
    });

    test('a non-matching term still returns nothing', () async {
      await seed(id: 'c1', shopName: storedName);

      expect(await search('ភ្នំពេញ'), isEmpty,
          reason: 'stripping must not turn search into a match-anything');
    });
  });
}
