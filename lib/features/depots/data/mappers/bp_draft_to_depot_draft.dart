import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_contact.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_sales_area.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';

/// The wizard's form as the body of `POST /api/v1/mobile/depots`.
///
/// Sends what the backend's `DepotDraftInput` accepts and nothing else. The
/// form still collects SAP fields that contract has no place for — grouping,
/// title, sales group, price group, delivery priority, tax class, VAT TIN,
/// currency — and the sales survey; those stay on the device, unsent.
extension BpDraftToDepotDraft on BpDepotDraft {
  /// [id] is the form's [BpDepotDraft.clientDraftId].
  NewDepotDraft toNewDepotDraft({required String id}) {
    final fix = geoFix;
    return NewDepotDraft(
      id: id,
      kind: switch (registrationType) {
        DepotRegistrationType.depot => MobileDepotKind.depot,
        DepotRegistrationType.nonBp => MobileDepotKind.nonDepot,
      },
      depots: List.unmodifiable(supplyingDepots),
      nameEn: nameEn,
      nameKh: nameKh,
      searchTerm1: searchTerm,
      searchTerm2: searchTerm2,
      telephone: effectiveTelephone,
      mobilePhone: mobilePhone,
      faxNumber: faxNumber,
      address: DepotDraftAddress(
        provinceCode: cityCode ?? '',
        districtCode: districtCode,
        // The selector can resolve a commune before the code field is set.
        communeCode: communeCode ?? geoAddress?.commune?.code,
        villageCode: villageCode,
        street: [houseNumber.trim(), street.trim()]
            .where((part) => part.isNotEmpty)
            .join(' '),
      ),
      location: fix == null
          ? null
          : DepotDraftLocation(
              latitude: fix.latitude,
              longitude: fix.longitude,
              accuracyMeters: fix.accuracyMeters,
            ),
      contacts: [
        if (_contact case final contact?) contact,
      ],
      salesAreas: [
        DepotDraftSalesArea(
          key: 'sales-area-1',
          salesOrg: salesOrg,
          distributionChannel: distributionChannel,
          division: divisionCode,
          // The form's "depot group" is SAP's customer group.
          customerGroup: depotGroup,
          salesOffice: salesOffice,
          shippingCondition: shippingCondition,
          paymentTerms: paymentTerm,
          // Left empty: the server fills in the signed-in rep's own code and
          // refuses anyone else's.
        ),
      ],
      creditLimit: creditLimit,
      remarks: remark,
    );
  }

  /// The one contact person the form captures, as the primary contact.
  DepotDraftContact? get _contact {
    final name = contactPersonName.trim();
    if (name.isEmpty) return null;
    final isKhmer = RegExp(r'[ក-៿]').hasMatch(name);
    return DepotDraftContact(
      key: 'contact-1',
      nameEn: isKhmer ? null : name,
      nameKh: isKhmer ? name : null,
      role: contactRoleFor(contactPersonRole),
      phoneNumber: mobilePhone,
      isPrimary: true,
    );
  }

  /// The form's role codes (`SapBpConst.contactRoles`) as the backend's six.
  static DepotContactRole contactRoleFor(String? code) => switch (code) {
        'owner' => DepotContactRole.owner,
        'manager' => DepotContactRole.manager,
        'buyer' => DepotContactRole.purchaser,
        'accountant' => DepotContactRole.accountant,
        _ => DepotContactRole.other,
      };
}
