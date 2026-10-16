import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_to_business_partner.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/domain/entities/sap_master_data.dart';

/// Business defaults for a new registration: payment term 14 day due net, and
/// no credit limit on the form — HQ sets it in SAP, so the app always sends
/// 0.00.
const _rep = RepSalesContext(
  salesOrganization: '0001',
  salesOrganizationName: 'Phnom Penh (ISI)',
  salesOffice: '0001',
  salesOfficeName: 'Phnom Penh',
  salesEmployeeId: '107576',
  salesEmployeeName: 'Mengchou CHORN',
);

void main() {
  test('a new draft defaults to 14 day due net', () {
    expect(BpDepotDraft().paymentTerm, 'T014');
    expect(
      SapMasterData.paymentTerm.any((o) => o.code == 'T014'),
      isTrue,
      reason: 'the default must be a code the offline list knows',
    );
  });

  test('the rep can still change the payment term', () {
    final request = (BpDepotDraft()..paymentTerm = 'TCOD')
        .toBusinessPartnerRequest(rep: _rep);

    expect(request.paymentTerms, 'TCOD');
  });

  test('sends a 0.00 credit limit', () {
    final request = BpDepotDraft().toBusinessPartnerRequest(rep: _rep);

    expect(request.creditLimit, '0.00');
    expect(request.paymentTerms, 'T014');
  });

  test('a draft saved with a picked limit still sends 0.00', () {
    final request = (BpDepotDraft()..creditLimit = 50000)
        .toBusinessPartnerRequest(rep: _rep);

    expect(request.creditLimit, '0.00');
  });
}
