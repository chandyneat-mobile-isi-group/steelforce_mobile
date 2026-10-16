import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_to_business_partner.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/domain/entities/sap_bp_const.dart';

/// `CoName` on the registration is the step-3 contact person as `Name-Role`.
const _rep = RepSalesContext(
  salesOrganization: '0001',
  salesOrganizationName: 'Phnom Penh (ISI)',
  salesOffice: '0001',
  salesOfficeName: 'Phnom Penh',
  salesEmployeeId: '107576',
  salesEmployeeName: 'Mengchou CHORN',
);

BpDepotDraft _draft({String name = 'Sok Dara', String? role = 'owner'}) =>
    BpDepotDraft()
      ..contactPersonName = name
      ..contactPersonRole = role;

void main() {
  test('sends the contact as Name-Role in CoName', () {
    final request = _draft().toBusinessPartnerRequest(rep: _rep);

    expect(request.coName, 'Sok Dara-Owner');
  });

  test('uses the English role label, not the code', () {
    expect(_draft(role: 'accountant').contactCoName, 'Sok Dara-Accountant');
  });

  test('trims the name', () {
    expect(_draft(name: '  Sok Dara  ').contactCoName, 'Sok Dara-Owner');
  });

  test('no role picked: the name alone', () {
    expect(_draft(role: null).contactCoName, 'Sok Dara');
  });

  test('no name: CoName is empty', () {
    final request = _draft(name: '  ').toBusinessPartnerRequest(rep: _rep);

    expect(request.coName, isEmpty);
  });

  test('a long name is shortened so the role still fits in 40 characters', () {
    final value = _draft(name: 'A' * 60, role: 'manager').contactCoName;

    expect(value.length, SapBpConst.coNameMaxLength);
    expect(value, endsWith('-Manager'));
  });

  test('an old draft with a typed c/o name sends the contact instead', () {
    final request = (_draft()..coName = 'Old company name')
        .toBusinessPartnerRequest(rep: _rep);

    expect(request.coName, 'Sok Dara-Owner');
  });
}
