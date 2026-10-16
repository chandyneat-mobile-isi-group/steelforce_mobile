import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';

/// The cascading-reset and integrity rules (§8, §10, §14) live in [GeoAddress],
/// so they are tested here — with no bloc, no database and no widget. That is
/// the point of putting them in the entity: the rule that must never be got
/// wrong is the one with the cheapest test.

GeoUnit _unit(
  GeoLevel level,
  String code, {
  String en = 'Name',
  String km = 'ឈ្មោះ',
  String? postal,
  String unit = 'Unit',
}) =>
    GeoUnit(
      level: level,
      code: code,
      name: LocalizedText(en: en, km: km),
      unit: unit,
      postalCode: postal,
    );

// Phnom Penh → Chamkar Mon → Tonle Basak → a village in it.
final _pp = _unit(GeoLevel.province, '12', en: 'Phnom Penh', unit: 'Capital');
final _chamkarMon =
    _unit(GeoLevel.district, '1201', en: 'Chamkar Mon', unit: 'Khan');
final _tonleBasak = _unit(GeoLevel.commune, '120101',
    en: 'Tonle Basak', unit: 'Sangkat', postal: '120101');
final _village =
    _unit(GeoLevel.village, '12010101', en: 'Ou Thum', unit: 'Village');

// A second province and its district, for the "change the parent" cases.
final _kandal = _unit(GeoLevel.province, '08', en: 'Kandal');
final _kandalDistrict = _unit(GeoLevel.district, '0801', en: 'Kandal Stueng');

GeoAddress get _full => const GeoAddress()
    .select(GeoLevel.province, _pp)
    .select(GeoLevel.district, _chamkarMon)
    .select(GeoLevel.commune, _tonleBasak)
    .select(GeoLevel.village, _village);

void main() {
  group('cascading reset (§8)', () {
    test('changing the province clears district, commune, village and postal',
        () {
      final reset = _full.select(GeoLevel.province, _kandal);

      expect(reset.province, _kandal);
      expect(reset.district, isNull);
      expect(reset.commune, isNull);
      expect(reset.village, isNull);
      expect(reset.postalCode, isNull);
    });

    test('changing the district clears commune and village but keeps province',
        () {
      final reset = _full.select(GeoLevel.district, _kandalDistrict);

      expect(reset.province, _pp);
      expect(reset.district, _kandalDistrict);
      expect(reset.commune, isNull);
      expect(reset.village, isNull);
      expect(reset.postalCode, isNull);
    });

    test('changing the commune clears only the village', () {
      final other = _unit(GeoLevel.commune, '120102',
          en: 'Boeng Keng Kang 1', postal: '120102');
      final reset = _full.select(GeoLevel.commune, other);

      expect(reset.district, _chamkarMon);
      expect(reset.commune, other);
      expect(reset.village, isNull);
      expect(reset.postalCode, '120102', reason: 'postal follows the commune');
    });

    test('clearing a level clears its children exactly as changing it does',
        () {
      final cleared = _full.select(GeoLevel.district, null);

      expect(cleared.province, _pp);
      expect(cleared.district, isNull);
      expect(cleared.commune, isNull);
      expect(cleared.village, isNull);
    });

    test('a manually typed postal code does not survive a commune change', () {
      final manual = const GeoAddress()
          .select(GeoLevel.province, _pp)
          .select(GeoLevel.district, _chamkarMon)
          .select(GeoLevel.commune,
              _unit(GeoLevel.commune, '120109', en: 'No Postal'))
          .withManualPostalCode('120199');
      expect(manual.postalCode, '120199');

      final changed = manual.select(GeoLevel.commune, _tonleBasak);
      expect(changed.manualPostalCode, isNull);
      expect(changed.postalCode, '120101');
    });

    test('selecting a deeper level leaves its ancestors alone', () {
      final withVillage = const GeoAddress()
          .select(GeoLevel.province, _pp)
          .select(GeoLevel.district, _chamkarMon)
          .select(GeoLevel.commune, _tonleBasak)
          .select(GeoLevel.village, _village);

      expect(withVillage.province, _pp);
      expect(withVillage.district, _chamkarMon);
      expect(withVillage.commune, _tonleBasak);
    });
  });

  group('postal code derivation', () {
    test('is taken from the commune and reported as derived', () {
      expect(_full.postalCode, '120101');
      expect(_full.isPostalCodeDerived, isTrue);
      expect(_full.needsManualPostalCode, isFalse);
    });

    test('a commune with no code asks for manual entry rather than guessing',
        () {
      final address = const GeoAddress()
          .select(GeoLevel.province, _pp)
          .select(GeoLevel.district, _chamkarMon)
          .select(GeoLevel.commune,
              _unit(GeoLevel.commune, '120199', en: 'Uncovered'));

      expect(address.postalCode, isNull);
      expect(address.isPostalCodeDerived, isFalse);
      expect(address.needsManualPostalCode, isTrue);
    });

    test('the commune wins over a stored code', () {
      final address = _full.withManualPostalCode('99999');
      expect(address.postalCode, '120101');
    });

    test('a blank manual entry is treated as absent, not as an empty code', () {
      final address = const GeoAddress()
          .select(GeoLevel.province, _pp)
          .select(GeoLevel.district, _chamkarMon)
          .select(GeoLevel.commune,
              _unit(GeoLevel.commune, '120199', en: 'Uncovered'))
          .withManualPostalCode('   ');
      expect(address.postalCode, isNull);
    });
  });

  group('hierarchy integrity (§14)', () {
    test('a consistent address is intact', () {
      expect(_full.isHierarchyIntact, isTrue);
      expect(_full.validate(), isEmpty);
    });

    test('a district from another province is rejected', () {
      // Constructed directly — the cascade cannot produce this, which is
      // exactly why the check exists for data arriving from elsewhere.
      const address = GeoAddress();
      final broken = GeoAddress(
        province: _pp,
        district: _kandalDistrict, // '0801' is not under '12'
      );
      expect(address.isHierarchyIntact, isTrue);
      expect(broken.isHierarchyIntact, isFalse);
      expect(broken.validate(), contains(GeoAddressError.brokenHierarchy));
    });

    test('a village whose commune is missing is rejected', () {
      final broken = GeoAddress(
        province: _pp,
        district: _chamkarMon,
        village: _village,
      );
      expect(broken.isHierarchyIntact, isFalse);
    });

    test('isChildOf checks the code prefix and the code length', () {
      expect(_chamkarMon.isChildOf('12'), isTrue);
      expect(_chamkarMon.isChildOf('08'), isFalse);
      // '120' is not a province code even though the prefix matches.
      expect(_chamkarMon.isChildOf('120'), isFalse);
    });
  });

  group('validation (§10)', () {
    test('the standard requirement needs province, district and commune', () {
      final errors = GeoAddress.empty.validate();
      expect(
        errors,
        containsAll([
          GeoAddressError.missingProvince,
          GeoAddressError.missingDistrict,
          GeoAddressError.missingCommune,
        ]),
      );
      expect(errors, isNot(contains(GeoAddressError.missingVillage)));
    });

    test('a delivery address also needs the village', () {
      final withoutVillage = const GeoAddress()
          .select(GeoLevel.province, _pp)
          .select(GeoLevel.district, _chamkarMon)
          .select(GeoLevel.commune, _tonleBasak);

      expect(withoutVillage.isValid(), isTrue);
      expect(withoutVillage.isValid(GeoAddressRequirement.delivery), isFalse);
      expect(
        withoutVillage.validate(GeoAddressRequirement.delivery),
        contains(GeoAddressError.missingVillage),
      );
    });

    test(
        'an undeterminable postal code blocks submission rather than passing '
        'an empty one', () {
      final address = const GeoAddress()
          .select(GeoLevel.province, _pp)
          .select(GeoLevel.district, _chamkarMon)
          .select(GeoLevel.commune,
              _unit(GeoLevel.commune, '120199', en: 'Uncovered'));

      expect(
        address.validate(),
        contains(GeoAddressError.postalCodeUnavailable),
      );
      // …and is satisfied once the rep supplies one.
      expect(address.withManualPostalCode('120199').validate(), isEmpty);
    });

    test('every failing rule is reported, not just the first', () {
      expect(GeoAddress.empty.validate().length, greaterThan(1));
    });

    test('the optional requirement accepts an empty address', () {
      expect(GeoAddress.empty.isValid(GeoAddressRequirement.optional), isTrue);
    });
  });

  group('submission payload (§15)', () {
    test('carries codes, not names', () {
      expect(_full.toCodeMap(), {
        'provinceCode': '12',
        'districtCode': '1201',
        'communeCode': '120101',
        'villageCode': '12010101',
        'postalCode': '120101',
      });
    });

    test('formats deepest-first in each language', () {
      expect(
        _full.format('en'),
        'Village Ou Thum, Sangkat Tonle Basak, Khan Chamkar Mon, Capital Phnom Penh',
      );
      expect(_full.format('km'), startsWith('ភូមិ'));
      expect(_full.format('km'), contains('សង្កាត់'));
    });

    test('formats a partial address without leaving gaps', () {
      final partial = const GeoAddress().select(GeoLevel.province, _pp);
      expect(partial.format('en'), 'Capital Phnom Penh');
    });
  });

  group('GeoLevel', () {
    test('deeperLevels lists exactly the dependent levels', () {
      expect(GeoLevel.province.deeperLevels,
          [GeoLevel.district, GeoLevel.commune, GeoLevel.village]);
      expect(GeoLevel.commune.deeperLevels, [GeoLevel.village]);
      expect(GeoLevel.village.deeperLevels, isEmpty);
    });

    test('code lengths match the NCDD scheme', () {
      expect(GeoLevel.province.codeLength, 2);
      expect(GeoLevel.district.codeLength, 4);
      expect(GeoLevel.commune.codeLength, 6);
      expect(GeoLevel.village.codeLength, 8);
    });
  });
}
