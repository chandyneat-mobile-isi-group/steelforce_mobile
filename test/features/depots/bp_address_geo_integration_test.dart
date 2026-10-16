import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_json_mapper.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_to_business_partner.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/bp_form_step.dart';
import 'package:steelforce/features/depots/domain/entities/geo_fix.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';

/// Step 2 of the BP form now captures its address through the shared gazetteer
/// component. These are the seams between the two: what reaches SAP, and what
/// blocks the step.

GeoUnit _u(
  GeoLevel level,
  String code,
  String en, {
  String unit = 'Unit',
  String? postal,
}) =>
    GeoUnit(
      level: level,
      code: code,
      name: LocalizedText(en: en, km: en),
      unit: unit,
      postalCode: postal,
    );

final _address = GeoAddress(
  province: _u(GeoLevel.province, '12', 'Phnom Penh', unit: 'Capital'),
  district: _u(GeoLevel.district, '1201', 'Chamkar Mon', unit: 'Khan'),
  commune: _u(GeoLevel.commune, '120101', 'Tonle Basak',
      unit: 'Sangkat', postal: '120101'),
  village: _u(GeoLevel.village, '12010101', 'Ou Thum', unit: 'Village'),
);

BpDepotDraft _draft({GeoAddress? address, String street = 'Street 271'}) {
  final a = address ?? _address;
  return BpDepotDraft(
    nameEn: 'Sok Heng Hardware',
    nameKh: 'ហាង សុខ ហេង',
    street: street,
    houseNumber: '45',
    cityCode: a.province?.code,
    districtCode: a.district?.code,
    communeCode: a.commune?.code,
    villageCode: a.village?.code,
    postalCode: a.postalCode ?? '',
    geoAddress: a,
    geoFix: GeoFix(
      latitude: 11.55,
      longitude: 104.92,
      capturedAt: DateTime.utc(2026, 8, 27),
    ),
    mobilePhone: '012345678',
    contactPersonName: 'Sok',
  );
}

const _rep = RepSalesContext(
  salesOrganization: '1000',
  salesOrganizationName: 'Phnom Penh (ISI)',
  salesOffice: '0001',
  salesOfficeName: 'Phnom Penh',
  salesEmployeeId: '107576',
  salesEmployeeName: 'Mengchou CHORN',
);

/// The wire body exactly as the endpoint receives it: draft → request →
/// PascalCase JSON. It goes through the mapper because that is now the single
/// place the outbound shape is built — `toSapPayload` was deleted rather than
/// deprecated, since it emitted camelCase keys the live endpoint drops in
/// silence.
Map<String, dynamic> _payload(BpDepotDraft draft) =>
    BusinessPartnerRequestModel.fromEntity(
      draft.toBusinessPartnerRequest(rep: _rep),
    ).toJson();

void main() {
  group('SAP payload', () {
    test('sends province and district as their own fields, by name', () {
      // `City` and `District` carry the English *name*, not the gazetteer
      // code: SAP's address structure stores free-text place names and has no
      // notion of Cambodia's numeric codes. The postal code stays a code.
      final payload = _payload(_draft());
      expect(payload['City'], 'Phnom Penh');
      expect(payload['District'], 'Chamkar Mon');
      expect(payload['PostalCode'], '120101');
    });

    test('folds commune and village into street — SAP has no field for them',
        () {
      final payload = _payload(_draft());
      expect(
          payload['Street'], 'Street 271, Phum Ou Thum, Sangkat Tonle Basak');
    });

    test('does not send commune or village as their own keys', () {
      // SAP's BP structure has no such fields; sending them would leave the
      // two levels to be dropped by a middleware that does not model them.
      final payload = _payload(_draft());
      expect(payload.containsKey('Commune'), isFalse);
      expect(payload.containsKey('Village'), isFalse);
    });

    test('uses Khum for a commune and Sangkat for a sangkat', () {
      final rural = GeoAddress(
        province: _u(GeoLevel.province, '01', 'Banteay Meanchey'),
        district: _u(GeoLevel.district, '0102', 'Mongkol Borei'),
        commune: _u(GeoLevel.commune, '010201', 'Banteay Neang',
            unit: 'Commune', postal: '010201'),
      );
      final payload = _payload(_draft(address: rural));
      expect(payload['Street'], endsWith('Khum Banteay Neang'));
    });

    test('omits the levels that are not selected', () {
      final partial = GeoAddress(
        province: _address.province,
        district: _address.district,
        commune: _address.commune,
      );
      final payload = _payload(_draft(address: partial));
      expect(payload['Street'], 'Street 271, Sangkat Tonle Basak');
    });

    test('stays within SAP\'s 60-character street field', () {
      final payload = _payload(_draft(street: 'A' * 80));
      expect((payload['Street'] as String).length, lessThanOrEqualTo(60));
    });

    test(
        'keeps the street text when truncating, since it truncates from the '
        'end', () {
      final payload = _payload(_draft(street: 'National Road 5, Building C'));
      expect(payload['Street'], startsWith('National Road 5, Building C'));
    });
  });

  group('address-step validation', () {
    test('a complete address passes', () {
      expect(_draft().validateStep(BpFormStep.address), isEmpty);
    });

    test('a missing commune blocks the step', () {
      final draft = _draft()
        ..communeCode = null
        ..geoAddress = GeoAddress(
          province: _address.province,
          district: _address.district,
        );
      expect(draft.validateStep(BpFormStep.address), contains('commune'));
    });

    test('a missing district blocks the step', () {
      final draft = _draft()..districtCode = null;
      expect(draft.validateStep(BpFormStep.address), contains('district'));
    });

    test(
        'an undeterminable postal code blocks the step rather than being '
        'guessed from the district', () {
      // The 99 communes Cambodia Post does not cover. The old behaviour filled
      // this from a per-district table holding superseded five-digit codes —
      // a code for a different place.
      final uncovered = GeoAddress(
        province: _address.province,
        district: _address.district,
        commune: _u(GeoLevel.commune, '120199', 'Uncovered', unit: 'Sangkat'),
      );
      final draft = _draft(address: uncovered)..postalCode = '';

      final errors = draft.validateStep(BpFormStep.address);
      expect(errors, contains('postalCode'));
      expect(draft.postalCode, isEmpty,
          reason: 'applyDerivations must not invent one');

      // …and passes once the rep supplies the real code.
      draft.postalCode = '120199';
      expect(draft.validateStep(BpFormStep.address),
          isNot(contains('postalCode')));
    });

    test('applyDerivations no longer touches the postal code', () {
      final draft = _draft()..postalCode = '';
      draft.applyDerivations();
      expect(draft.postalCode, isEmpty);
    });

    test('accepts a six-digit code and still accepts a stored five-digit one',
        () {
      final draft = _draft()..postalCode = '120101';
      expect(draft.validateStep(BpFormStep.address),
          isNot(contains('postalCode')));

      // A draft saved under the superseded scheme must not strand the rep.
      draft.postalCode = '12000';
      expect(draft.validateStep(BpFormStep.address),
          isNot(contains('postalCode')));

      draft.postalCode = '12';
      expect(draft.validateStep(BpFormStep.address), contains('postalCode'));
    });
  });

  group('server draft round trip', () {
    test('restores province, district and postal code from the server fields',
        () {
      final draft = BpDepotDraft();
      applyBpServerFields(draft, {
        'city': '12',
        'district': '1201',
        'postalCode': '120101',
      });

      expect(draft.cityCode, '12');
      expect(draft.districtCode, '1201');
      expect(draft.postalCode, '120101');
    });
  });
}
