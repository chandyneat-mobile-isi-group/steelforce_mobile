import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/sap_master_data.dart';
import 'package:steelforce/features/depots/domain/entities/sap_option.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart';

/// The registration dropdowns must prefer the ERP's own catalogues, and must
/// still work without them.
///
/// Both halves matter and pull in opposite directions:
///
///  * The built-in lists are materially shorter than SAP's — payment terms
///    **4 vs 28**, depot groups **5 vs 8**, price groups **5 vs 9** — so a
///    rep picking from them can choose a code the push is rejected for, which
///    from the field is indistinguishable from a real rejection.
///  * But an empty dropdown blocks the registration outright, and a rep opening
///    the form for the first time with no signal has no cached catalogues. So
///    the built-in lists cannot simply be deleted; they are the floor.
///
/// See `docs/feature/depot/mobile/filter-depot.md`
/// §Where the filter values come from.
void main() {
  /// The `/references` payload shape: `data.catalogues` plus `synchronisedAt`.
  DepotReferenceCatalogue catalogue(Map<String, dynamic> catalogues,
          {String? synchronisedAt}) =>
      DepotReferenceCatalogue({
        'catalogues': catalogues,
        if (synchronisedAt != null) 'synchronisedAt': synchronisedAt,
      });

  group('parsing the payload', () {
    test('reads code/name pairs per catalogue', () {
      final options = SapReferenceOptions(catalogue({
        'PaymentTerm': [
          {'code': 'T030', 'name': '30 days due net'},
          {'code': 'T060', 'name': '60 days due net'},
        ],
      }));

      expect(options.paymentTerm.map((o) => o.code), ['T030', 'T060']);
      expect(options.paymentTerm.first.labelEn, '30 days due net');
      expect(options.isFromErp, isTrue);
    });

    test('reads synchronisedAt so staleness can be shown', () {
      final options = SapReferenceOptions(catalogue({
        'Division': [
          {'code': '10', 'name': 'ISI Steel'}
        ]
      }, synchronisedAt: '2026-08-28T03:00:10Z'));

      expect(options.synchronisedAt, DateTime.utc(2026, 8, 28, 3, 0, 10));
    });

    test('drops rows with no code rather than offering a blank choice', () {
      final options = SapReferenceOptions(catalogue({
        'Division': [
          {'code': '', 'name': 'Broken'},
          {'name': 'No code at all'},
          {'code': '10', 'name': 'ISI Steel'},
        ],
      }));

      expect(options.division.map((o) => o.code), ['10']);
    });

    test('falls back to the code when the ERP sends no name', () {
      final options = SapReferenceOptions(catalogue({
        'Division': [
          {'code': '10'}
        ],
      }));

      expect(options.division.single.labelEn, '10',
          reason: 'a nameless option must still be selectable, not blank');
    });

    test('a malformed catalogue is ignored, not fatal', () {
      final options = SapReferenceOptions(catalogue({
        'Division': 'not a list',
        'PaymentTerm': [
          {'code': 'T030', 'name': '30 days'}
        ],
      }));

      // Division falls back; PaymentTerm still comes from the ERP.
      expect(options.division, SapMasterData.division);
      expect(options.paymentTerm.single.code, 'T030');
    });
  });

  group('the ERP copy wins where it exists', () {
    test('the served list replaces the built-in one entirely', () {
      // The built-in lists have since been corrected against the live
      // catalogues, so this is no longer about closing a size gap — it is
      // about the ERP staying authoritative when SAP customising changes and
      // the app has not been redeployed.
      final erp = [
        {'code': 'T030', 'name': '30 days due net'},
        {'code': 'TX99', 'name': 'A term added in SAP since this build'},
      ];
      final options = SapReferenceOptions(catalogue({'PaymentTerm': erp}));

      expect(options.paymentTerm.map((o) => o.code), ['T030', 'TX99']);
      expect(
        options.paymentTerm.any((o) => o.code == 'BL30'),
        isFalse,
        reason: 'the built-in list must not be merged in — the ERP copy is '
            'the whole truth when it is present',
      );
    });
  });

  group('the built-in lists are the floor, never an empty dropdown', () {
    test('no catalogues loaded resolves every dropdown to a built-in list', () {
      const options = SapReferenceOptions.empty;

      expect(options.isFromErp, isFalse);
      expect(options.paymentTerm, SapMasterData.paymentTerm);
      expect(options.depotGroup, SapMasterData.depotGroup);
      expect(options.division, SapMasterData.division);
      expect(options.distributionChannel, SapMasterData.distributionChannel);
      expect(options.shippingCondition, SapMasterData.shippingCondition);
      expect(options.priceGroup, SapMasterData.priceGroup);
    });

    test('an empty catalogue list is treated as absent', () {
      final options =
          SapReferenceOptions(catalogue({'PaymentTerm': <dynamic>[]}));

      expect(options.paymentTerm, SapMasterData.paymentTerm,
          reason: 'an empty ERP list must not blank the dropdown');
    });

    test('a catalogue the ERP does not publish still resolves', () {
      // Only PaymentTerm arrives; the others must not vanish.
      final options = SapReferenceOptions(catalogue({
        'PaymentTerm': [
          {'code': 'T030'}
        ]
      }));

      expect(options.depotGroup, SapMasterData.depotGroup);
      expect(options.shippingCondition, SapMasterData.shippingCondition);
      expect(options.paymentTerm.single.code, 'T030');
    });

    test('every dropdown the form offers has a non-empty option list', () {
      const options = SapReferenceOptions.empty;

      for (final list in [
        options.paymentTerm,
        options.depotGroup,
        options.division,
        options.distributionChannel,
        options.shippingCondition,
        options.priceGroup,
      ]) {
        expect(list, isNotEmpty,
            reason: 'an empty dropdown blocks the registration entirely');
      }
    });
  });

  group('the sales area is now offered, not assumed', () {
    // These three used to come from the rep's session (`salesOrg`,
    // `salesOffice`) or a constant (`salesGroup` = '010'), so a rep registering
    // a shop in Battambang filed it against Phnom Penh. They are part of the
    // sales area SAP requires, and a wrong one is not a validation error — it
    // is a depot routed to the wrong office.

    test('SalesOrg comes through with all 22 ERP entries', () {
      final options = SapReferenceOptions(catalogue({
        'SalesOrg': [
          {'code': '0001', 'name': 'Phnom Penh (ISI)'},
          {'code': '0003', 'name': 'Battambang'},
          {'code': '9999', 'name': 'Internal'},
        ],
      }));

      expect(options.salesOrg.map((o) => o.code), ['0001', '0003', '9999']);
      expect(options.salesOrg[1].labelEn, 'Battambang');
    });

    test('SalesOffice and SalesGroup resolve too', () {
      final options = SapReferenceOptions(catalogue({
        'SalesOffice': [
          {'code': '0009', 'name': 'Siem Riep'}
        ],
        'SalesGroup': [
          {'code': '020', 'name': 'Project Sales'}
        ],
      }));

      expect(options.salesOffice.single.labelEn, 'Siem Riep');
      expect(options.salesGroup.single.labelEn, 'Project Sales');
    });

    test('all three fall back to a non-empty built-in list', () {
      const options = SapReferenceOptions.empty;

      expect(options.salesOrg, isNotEmpty);
      expect(options.salesOffice, isNotEmpty);
      expect(options.salesGroup, isNotEmpty);
    });
  });

  group('price group is matched by name, not by arithmetic on the code', () {
    /// The real pairing, from the live catalogues.
    SapReferenceOptions live() => SapReferenceOptions(catalogue({
          'DepotGroup': [
            {'code': '01', 'name': 'End-User'},
            {'code': '05', 'name': 'Contractor'},
            {'code': '07', 'name': 'Distributor'},
            {'code': '08', 'name': 'Exporter'},
          ],
          'PriceGroup': [
            {'code': '11', 'name': 'End-User'},
            {'code': '51', 'name': 'Contractor'},
            {'code': '52', 'name': 'Key Account'},
            {'code': '71', 'name': 'Distributor'},
          ],
        }));

    test('Contractor pairs with Contractor', () {
      // The old map sent '15' here -- a code SAP does not publish, so every
      // registration deriving one carried a price group the ERP would reject.
      expect(live().priceGroupFor('05'), '51');
    });

    test('End-User and Distributor pair by name too', () {
      expect(live().priceGroupFor('01'), '11');
      expect(live().priceGroupFor('07'), '71');
    });

    test('a depot group with no counterpart resolves to null, not a guess', () {
      // SAP publishes no Exporter price group. An unset value beats an
      // invented code the push is rejected for.
      expect(live().priceGroupFor('08'), isNull);
    });

    test('null in, null out', () {
      expect(live().priceGroupFor(null), isNull);
    });

    test('an unknown depot group does not invent a price group', () {
      expect(live().priceGroupFor('ZZ'), isNull);
    });

    test('without catalogues it falls back to the built-in pairing', () {
      const options = SapReferenceOptions.empty;

      // The built-in map, now corrected: 05 Contractor -> 51, not 15.
      expect(options.priceGroupFor('05'), '51');
      expect(options.priceGroupFor('01'), '11');
    });

    test('a built-in answer is rejected when the ERP does not list it', () {
      // The catalogue in hand has no '51', so the map's answer is discarded
      // rather than sent as a code this ERP does not know.
      final options = SapReferenceOptions(catalogue({
        'DepotGroup': [
          {'code': '05', 'name': 'Something Else'}
        ],
        'PriceGroup': [
          {'code': '11', 'name': 'End-User'}
        ],
      }));

      expect(options.priceGroupFor('05'), isNull);
    });
  });

  test('the built-in fallbacks match the live ERP catalogues', () {
    // Guards the correction made against the real payload: the previous lists
    // were guesses and every one of these was wrong.
    expect(SapMasterData.paymentTerm, hasLength(28));
    expect(SapMasterData.depotGroup, hasLength(8));
    expect(SapMasterData.priceGroup, hasLength(9));
    expect(SapMasterData.distributionChannel, hasLength(9));
    expect(SapMasterData.division, hasLength(5));
    expect(SapMasterData.shippingCondition, hasLength(2));
    expect(SapMasterData.salesOrg, hasLength(22));
    expect(SapMasterData.salesOffice, hasLength(20));
    expect(SapMasterData.salesGroup, hasLength(6));
  });

  group('credit approval keys off real payment terms', () {
    test('cash terms need no approval', () {
      expect(SapMasterData.paymentTermNeedsCreditApproval('TCIA'), isFalse);
      expect(SapMasterData.paymentTermNeedsCreditApproval('TCOD'), isFalse);
    });

    test('net and LC terms do', () {
      expect(SapMasterData.paymentTermNeedsCreditApproval('T030'), isTrue);
      expect(SapMasterData.paymentTermNeedsCreditApproval('BL90'), isTrue);
    });

    test('an unfamiliar term is treated as credit, not waved through', () {
      // Fail-closed: a term this build has not seen is more safely routed
      // through an approval it did not need than skipped as cash it was not.
      expect(SapMasterData.paymentTermNeedsCreditApproval('T999'), isTrue);
    });

    test('the old rule would have called every real term a credit sale', () {
      // `code != 'T00'` against a list whose only cash term was 'T00' -- a code
      // SAP does not publish. Cash on delivery went to HQ for approval.
      expect(SapMasterData.paymentTerm.any((o) => o.code == 'T00'), isFalse);
    });
  });

  group('a stored code that left the catalogue', () {
    // The crash this guards: a resumed server draft still carrying `T00` after
    // the payment terms were corrected against the live catalogue.
    // `DropdownButton` asserts that exactly one item matches its value, so an
    // unmatched code took down the whole registration form.
    //
    // The widget-level fix keeps the value visible as an unrecognised option;
    // this pins the data-level half — that such a code really is absent, so the
    // guard is load-bearing rather than defensive decoration.

    test('T00 is genuinely gone from the payment terms', () {
      expect(SapMasterData.paymentTerm.any((o) => o.code == 'T00'), isFalse);
    });

    test('the retired price-group codes are gone too', () {
      // 12, 13, 14, 15 were the old derivation targets. A draft saved under
      // them would hit the same assert on the price-group dropdown.
      for (final retired in const ['12', '13', '14', '15']) {
        expect(SapMasterData.priceGroup.any((o) => o.code == retired), isFalse,
            reason: 'price group $retired no longer exists in SAP');
      }
    });

    test('the default payment term is one the list actually offers', () {
      // The constructor default must always resolve, or every new form opens
      // on a value the dropdown cannot render.
      final draft = BpDepotDraft();
      expect(
        SapMasterData.paymentTerm.any((o) => o.code == draft.paymentTerm),
        isTrue,
        reason: 'the default payment term must exist in the built-in list',
      );
    });

    test('every other constructor default resolves in its own list', () {
      final draft = BpDepotDraft();
      bool offered(List<SapOption> options, String? code) =>
          code == null || options.any((o) => o.code == code);

      expect(offered(SapMasterData.grouping, draft.grouping), isTrue);
      expect(offered(SapMasterData.title, draft.title), isTrue);
      expect(
          offered(SapMasterData.distributionChannel, draft.distributionChannel),
          isTrue);
      expect(offered(SapMasterData.division, draft.divisionCode), isTrue);
      expect(offered(SapMasterData.deliveryPriority, draft.deliveryPriority),
          isTrue);
      expect(offered(SapMasterData.shippingCondition, draft.shippingCondition),
          isTrue);
      expect(offered(SapMasterData.taxClass, draft.taxClass), isTrue);
      expect(offered(SapMasterData.currency, draft.currency), isTrue);
    });
  });
}
