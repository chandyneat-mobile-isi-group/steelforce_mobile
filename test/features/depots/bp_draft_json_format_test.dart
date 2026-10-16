import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_json_mapper.dart';
import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/geo_fix.dart';

/// Pins the on-device saved-draft format byte for byte.
///
/// Drafts are written to the encrypted cache and into the registration
/// outbox, and an app update must load every draft an older version wrote.
/// These literals are what the format *is*; a refactor that changes any key
/// or value here strands drafts already on reps' phones.
BpDepotDraft _filled() => BpDepotDraft(
      nameEn: 'Bayon Steel',
      nameKh: 'បាយ័ន',
      name2: 'Branch 2',
      searchTerm: 'PHNOM PENH',
      searchTerm2: 'BAYON SENSOK',
      coName: 'legacy',
      depotNumber: '1000123',
      street: 'St 271',
      houseNumber: '12A',
      cityCode: '12',
      districtCode: '1204',
      communeCode: '120401',
      villageCode: '12040101',
      postalCode: '120401',
      geoFix: GeoFix(
        latitude: 11.55,
        longitude: 104.91,
        capturedAt: DateTime.utc(2026, 5, 1),
      ),
      language: 'E',
      regionCode: 'R02',
      mobilePhone: '012345678',
      telephone: '023999999',
      telephoneSameAsMobile: false,
      faxNumber: '023888888',
      contactPersonName: 'Sok Dara',
      contactPersonRole: 'OWN',
      salesOrg: '1000',
      salesOffice: 'S100',
      salesGroupCode: 'G01',
      distributionChannel: '20',
      divisionCode: '30',
      depotGroup: '01',
      priceGroup: '21',
      deliveryPriority: '02',
      shippingCondition: '03',
      paymentTerm: 'NT30',
      taxClass: '1',
      vatTin: 'K001-123',
      currency: 'KHR',
      creditLimit: 5000,
      serverDepotId: 'srv-9',
      isPendingHqApproval: true,
      remark: 'corner shop',
      attachments: [
        BpAttachment(
          kind: 'outlet_front',
          localPath: '/docs/front.jpg',
          remoteUrl: 'https://cdn/front.jpg',
          isUploaded: true,
          capturedAt: DateTime.utc(2026, 5, 1, 8),
        ),
        BpAttachment(
          kind: 'id_card',
          localPath: '/docs/id.jpg',
          capturedAt: DateTime.utc(2026, 5, 1, 9),
        ),
      ],
    )..priceGroupOverridden = true;

const _filledJson = <String, dynamic>{
  'accountGroup': 'Z001',
  'title': '0003',
  'name1': 'Bayon Steel',
  'name2': 'Branch 2',
  'name3': 'បាយ័ន',
  'coName': 'legacy',
  'searchTerm1': 'PHNOM PENH',
  'searchTerm2': 'BAYON SENSOK',
  'depotNumber': '1000123',
  'street': 'St 271',
  'houseNo': '12A',
  'city': '12',
  'district': '1204',
  'commune': '120401',
  'village': '12040101',
  'postalCode': '120401',
  'region': 'R02',
  'language': 'E',
  'mobilePhone': '012345678',
  'telephone': '023999999',
  'telephoneSameAsMobile': false,
  'faxNumber': '023888888',
  'contactPersonName': 'Sok Dara',
  'contactPersonRole': 'OWN',
  'salesOrg': '1000',
  'salesOffice': 'S100',
  'salesGroup': 'G01',
  'distributionChannel': '20',
  'division': '30',
  'depotGroup': '01',
  'priceGroup': '21',
  'priceGroupOverridden': true,
  'deliveryPriority': '02',
  'shippingCondition': '03',
  'paymentTerms': 'NT30',
  'taxClass': '1',
  'vatTin': 'K001-123',
  'currency': 'KHR',
  'creditLimit': 5000.0,
  'serverDepotId': 'srv-9',
  'isPendingHqApproval': true,
  'remark': 'corner shop',
  'latitude': 11.55,
  'longitude': 104.91,
  'attachments': [
    {
      'kind': 'outlet_front',
      'local_path': '/docs/front.jpg',
      'url': 'https://cdn/front.jpg',
      'is_uploaded': true,
      'captured_at': '2026-05-01T08:00:00.000Z',
    },
    {
      'kind': 'id_card',
      'local_path': '/docs/id.jpg',
      'is_uploaded': false,
      'captured_at': '2026-05-01T09:00:00.000Z',
    },
  ],
};

void main() {
  group('write', () {
    test('a filled draft writes exactly the pinned keys and values', () {
      expect(bpDraftToJson(_filled()), _filledJson);
    });

    test('an empty draft omits creditLimit and serverDepotId', () {
      final json = bpDraftToJson(BpDepotDraft());

      expect(json.containsKey('creditLimit'), isFalse);
      expect(json.containsKey('serverDepotId'), isFalse);
      expect(json['latitude'], isNull);
      expect(json['attachments'], isEmpty);
      expect(json['salesOrg'], isNotNull, reason: 'constructor default');
      expect(json.length, _filledJson.length - 2);
    });
  });

  group('read', () {
    test('the pinned JSON loads back into the same draft', () {
      final d = bpDraftFromJson(Map<String, dynamic>.from(_filledJson));

      expect(bpDraftToJson(d), _filledJson);
      expect(d.geoFix!.latitude, 11.55);
      expect(d.attachments.first.isUploaded, isTrue);
      expect(d.attachments.last.remoteUrl, isNull);
      expect(d.priceGroupOverridden, isTrue);
      expect(d.isPendingHqApproval, isTrue);
      expect(d.serverDepotId, 'srv-9');
    });

    test('an older, sparse draft loads with defaults for what it lacks', () {
      final d = bpDraftFromJson({
        'name1': 'Old Shop',
        'postalCode': '12000', // superseded five-digit scheme
        'communeCode': 'C1', // legacy key
        'villageCode': 'V1', // legacy key
        'creditLimit': '2500.5', // stored as a string by an old build
        'telephone': '',
        'mobilePhone': '011',
        'serverDepotId': '',
        'attachments': [
          {'kind': 'outlet_front', 'local_path': ''}, // no file: skipped
          {'kind': 'id_card', 'local_path': '/a.jpg', 'captured_at': 'bad'},
          'not a map',
        ],
      });

      expect(d.nameEn, 'Old Shop');
      expect(d.postalCode, '12000');
      expect(d.communeCode, 'C1');
      expect(d.villageCode, 'V1');
      expect(d.creditLimit, 2500.5);
      expect(d.telephoneSameAsMobile, isTrue);
      expect(d.serverDepotId, isNull);
      expect(d.isPendingHqApproval, isFalse);
      expect(d.priceGroupOverridden, isFalse);
      expect(d.grouping, 'Z001');
      expect(d.salesOrg, BpDepotDraft().salesOrg);
      expect(d.geoFix, isNull);
      expect(d.attachments.map((a) => a.kind), ['id_card']);
    });

    test('server fields: accountGroup wins over partnerGroup', () {
      final d = BpDepotDraft();
      applyBpServerFields(d, {'partnerGroup': 'Z002', 'accountGroup': 'Z009'});
      expect(d.grouping, 'Z009');

      final e = BpDepotDraft();
      applyBpServerFields(e, {'partnerGroup': 'Z002'});
      expect(e.grouping, 'Z002');
    });

    test('server fields: present-but-empty keeps nullable codes', () {
      final d = BpDepotDraft(cityCode: '12', salesOrg: '1000');
      applyBpServerFields(
          d, {'city': '', 'salesOrg': null, 'telephone': '011'});

      expect(d.cityCode, '12');
      expect(d.salesOrg, '1000');
      expect(d.telephone, '011');
      expect(d.telephoneSameAsMobile, isFalse);
    });
  });
}
