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

void main() {
  group('BpDepotDraft address step validation', () {
    test('requires province, district, commune, postal code and gps', () {
      final draft = BpDepotDraft();
      final errors = draft.validateStep(BpFormStep.address);

      expect(errors['city'], 'error.required');
      expect(errors['district'], 'error.required');
      expect(errors['commune'], 'error.required');
      // Not `postal_5_digits`: the postal scheme is six digits now, and the
      // five-digit codes still accepted are legacy stored values, so the
      // message no longer names a length.
      expect(errors['postalCode'], 'error.postal_code');
      expect(errors['geo'], 'error.gps_required');
    });

    test(
        'accepts a valid gazetteer address with 6-digit postal code and cambodia gps fix',
        () {
      final draft = BpDepotDraft(
        cityCode: '12',
        districtCode: '1201',
        communeCode: '120101',
        postalCode: '120101',
        geoFix: GeoFix(
          latitude: 11.5564,
          longitude: 104.9282,
          capturedAt: DateTime.now(),
        ),
      );

      final errors = draft.validateStep(BpFormStep.address);
      expect(errors, isEmpty);
    });

    test('rejects gps outside Cambodia', () {
      final draft = BpDepotDraft(
        cityCode: '12',
        districtCode: '1201',
        communeCode: '120101',
        postalCode: '12010',
        geoFix: GeoFix(
          latitude: 37.7749, // San Francisco
          longitude: -122.4194,
          capturedAt: DateTime.now(),
        ),
      );

      final errors = draft.validateStep(BpFormStep.address);
      expect(errors['geo'], 'error.gps_outside_kh');
    });

    test('satisfies commune requirement when geoAddress has commune entity',
        () {
      final draft = BpDepotDraft(
        cityCode: '12',
        districtCode: '1201',
        postalCode: '12010',
        geoAddress: GeoAddress(
          province: const GeoUnit(
            level: GeoLevel.province,
            code: '12',
            name: LocalizedText(en: 'Phnom Penh', km: 'ភ្នំពេញ'),
            unit: 'Capital',
          ),
          district: const GeoUnit(
            level: GeoLevel.district,
            code: '1201',
            name: LocalizedText(en: 'Chamkar Mon', km: 'ចំការមន'),
            unit: 'Khan',
          ),
          commune: const GeoUnit(
            level: GeoLevel.commune,
            code: '120101',
            name: LocalizedText(en: 'Tonle Basak', km: 'ទន្លេបាសាក់'),
            unit: 'Sangkat',
            postalCode: '120101',
          ),
        ),
        geoFix: GeoFix(
          latitude: 11.5564,
          longitude: 104.9282,
          capturedAt: DateTime.now(),
        ),
      );

      final errors = draft.validateStep(BpFormStep.address);
      expect(errors, isEmpty);
    });
  });

  group('BpDepotDraft server fields and payload mapping', () {
    test('parses commune and village from server fields', () {
      final draft = BpDepotDraft();
      applyBpServerFields(draft, {
        'city': '12',
        'district': '1201',
        'commune': '120101',
        'village': '12010101',
        'postalCode': '12010',
        'deliveryPriority': '01',
        'shippingCondition': '02',
        'contactPersonName': 'John Doe',
        'contactPersonRole': '01',
      });

      expect(draft.cityCode, '12');
      expect(draft.districtCode, '1201');
      expect(draft.communeCode, '120101');
      expect(draft.villageCode, '12010101');
      expect(draft.postalCode, '12010');
      expect(draft.deliveryPriority, '01');
      expect(draft.shippingCondition, '02');
      expect(draft.contactPersonName, 'John Doe');
      expect(draft.contactPersonRole, '01');
    });

    test('the wire payload carries the address codes SAP has fields for', () {
      final draft = BpDepotDraft(
        street: 'Street 271',
        houseNumber: '217',
        cityCode: '12',
        districtCode: '1201',
        communeCode: '120101',
        villageCode: '12010101',
        postalCode: '12010',
        deliveryPriority: '01',
        shippingCondition: '02',
        contactPersonName: 'John Doe',
        contactPersonRole: '01',
      );

      const rep = RepSalesContext(
        salesOrganization: '0001',
        salesOrganizationName: 'Phnom Penh ISI',
        salesOffice: '0001',
        salesOfficeName: 'Phnom Penh',
        salesEmployeeId: '107576',
        salesEmployeeName: 'Sales Rep',
      );

      final payload = BusinessPartnerRequestModel.fromEntity(
        draft.toBusinessPartnerRequest(rep: rep),
      ).toJson();

      // With no gazetteer selection on the draft, City and District fall back
      // to the stored codes; with one they carry the place names instead.
      expect(payload['City'], '12');
      expect(payload['District'], '1201');
      expect(payload['Street'], 'Street 271');
      expect(payload['HouseNo'], '217');
      expect(payload['PostalCode'], '12010');
      expect(payload['DeliveryPriority'], '01');
      expect(payload['ShippingCondition'], '02');

      // Commune and village have no SAP field — they reach it folded into
      // Street, and only when the draft carries a GeoAddress to name them.
      expect(payload.containsKey('Commune'), isFalse);
      expect(payload.containsKey('Village'), isFalse);

      // The contact person is collected by step 3 and validated as required,
      // but this endpoint has no key for it, so it does not reach SAP. Asserted
      // rather than left silent: see docs/feature/depot/registration/business-partner-changes.md §7, which
      // tracks it as an open product decision.
      expect(payload.containsKey('ContactPersonName'), isFalse);
      expect(payload.containsKey('ContactPersonRole'), isFalse);
    });
  });
}
