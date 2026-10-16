import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/bp_form_step.dart';
import 'package:steelforce/features/depots/domain/entities/geo_fix.dart';

/// Pins each wizard step's error map, so moving the rules does not change
/// which field blocks "Next" or which message it shows.
void main() {
  BpAttachment photo(String kind) =>
      BpAttachment(kind: kind, localPath: '/$kind.jpg', isUploaded: true);

  test('an empty draft blocks every step but review', () {
    final d = BpDepotDraft();

    expect(d.validateStep(BpFormStep.identity), {
      'nameEn': 'error.required',
      'nameKh': 'error.required',
    });
    expect(d.validateStep(BpFormStep.address), {
      'city': 'error.required',
      'district': 'error.required',
      'commune': 'error.required',
      'postalCode': 'error.postal_code',
      'geo': 'error.gps_required',
    });
    expect(d.validateStep(BpFormStep.contact), {
      'mobilePhone': 'error.required',
      'contactPersonName': 'error.required',
      'contactPersonRole': 'error.required',
    });
    expect(d.validateStep(BpFormStep.salesTerms), {
      'depotGroup': 'error.required',
    });
    expect(d.validateStep(BpFormStep.documents), {
      'outlet_front': 'error.photo_required',
      'outlet_inside': 'error.photo_required',
      'id_card': 'error.photo_required',
    });
    expect(d.validateStep(BpFormStep.review), isEmpty);
    expect(d.isStepComplete(BpFormStep.review), isTrue);
    expect(d.isReadyToSubmit, isFalse);
  });

  test('identity: over-long English and non-Khmer names', () {
    final d = BpDepotDraft(nameEn: 'x' * 41, nameKh: 'Latin');
    expect(d.validateStep(BpFormStep.identity), {
      'nameEn': 'error.max_40',
      'nameKh': 'error.must_be_khmer',
    });
  });

  test('address: a fix outside Cambodia', () {
    final d = BpDepotDraft(
      cityCode: '12',
      districtCode: '1204',
      communeCode: '120401',
      postalCode: '120401',
      geoFix:
          GeoFix(latitude: 48.85, longitude: 2.35, capturedAt: DateTime(2026)),
    );
    expect(d.validateStep(BpFormStep.address), {'geo': 'error.gps_outside_kh'});
  });

  test('contact: a separate telephone must be filled', () {
    final d = BpDepotDraft(
      mobilePhone: '011',
      telephoneSameAsMobile: false,
      contactPersonName: 'Dara',
      contactPersonRole: 'OWN',
    );
    expect(d.validateStep(BpFormStep.contact), {'telephone': 'error.required'});
  });

  test('VAT-registered: needs a TIN and a VAT certificate', () {
    final d = BpDepotDraft(depotGroup: '01', taxClass: '1', attachments: [
      photo('outlet_front'),
      photo('outlet_inside'),
      photo('id_card'),
    ]);
    expect(d.validateStep(BpFormStep.salesTerms),
        {'vatTin': 'error.vat_tin_required'});
    expect(d.validateStep(BpFormStep.documents),
        {'vat_cert': 'error.photo_required'});
    expect(d.allRequiredAttachmentsUploaded, isFalse);

    d.attachments.add(photo('vat_cert'));
    expect(d.allRequiredAttachmentsUploaded, isTrue);
  });

  test('sales terms: a cleared field is required', () {
    final d = BpDepotDraft(depotGroup: '01', salesOrg: null, taxClass: null);
    expect(d.validateStep(BpFormStep.salesTerms), {
      'salesOrg': 'error.required',
      'taxClass': 'error.required',
    });
  });
}
