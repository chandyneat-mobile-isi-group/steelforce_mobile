import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_contact.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_sales_area.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';

/// The body of `POST /api/v1/mobile/depots` (`CreateMobileDepotRequest`), with
/// the backend's exact names. One body for both kinds: `depotType` picks, and
/// fields the other kind does not use are ignored by the server.
///
/// Blank optional text is **left out**, not sent as `""`: on create both mean
/// "empty", and leaving it out keeps the payload to what the rep entered.
/// Codes go out exactly as chosen. Local row keys never leave the device, and
/// neither do display names — the server takes codes only.
abstract final class NewDepotDraftRequest {
  static DataMap toJson(NewDepotDraft draft) => {
        'id': draft.id,
        'depotType': draft.kind.apiValue,
        if (draft.kind == MobileDepotKind.nonDepot)
          'depots': [
            for (final code in draft.depots)
              if (code.trim().isNotEmpty) code.trim(),
          ],
        'nameEn': draft.nameEn.trim(),
        ..._text('nameKh', draft.nameKh),
        ..._text('searchTerm1', draft.searchTerm1),
        ..._text('searchTerm2', draft.searchTerm2),
        'telephone': draft.telephone.trim(),
        ..._text('mobilePhone', draft.mobilePhone),
        ..._text('faxNumber', draft.faxNumber),
        ..._text('email', draft.email),
        'address': _address(draft.address),
        if (draft.location case final location? when location.isPlausible)
          'location': _location(location),
        'contacts': [for (final c in draft.contacts) _contact(c)],
        'salesAreas': [for (final a in draft.salesAreas) _salesArea(a)],
        if (draft.creditLimit case final limit?)
          // Two decimals, as the server stores it; avoids sending 0.1+0.2.
          'creditLimit': num.parse(limit.toStringAsFixed(2)),
        if (draft.creditTermDays case final days?) 'creditTermDays': days,
        ..._text('remarks', draft.remarks),
        if (draft.suppliers case final suppliers? when !suppliers.isEmpty)
          'suppliers': _suppliers(suppliers),
      };

  static DataMap _address(DepotDraftAddress a) => {
        'provinceCode': a.provinceCode,
        ..._text('districtCode', a.districtCode),
        ..._text('communeCode', a.communeCode),
        ..._text('villageCode', a.villageCode),
        ..._text('street', a.street),
      };

  static DataMap _location(DepotDraftLocation l) => {
        'latitude': l.latitude,
        'longitude': l.longitude,
        if (l.accuracyMeters case final accuracy?) 'accuracyMeters': accuracy,
      };

  static DataMap _contact(DepotDraftContact c) => {
        ..._text('id', c.id),
        ..._text('nameEn', c.nameEn),
        ..._text('nameKh', c.nameKh),
        'role': c.role.apiValue,
        ..._text('phoneNumber', c.phoneNumber),
        ..._text('email', c.email),
        'isPrimary': c.isPrimary,
      };

  /// `salesEmployee` is left out when blank: a sales rep's own code is filled
  /// in by the server, and sending another one is refused.
  static DataMap _salesArea(DepotDraftSalesArea a) => {
        ..._text('id', a.id),
        ..._text('salesOrg', a.salesOrg),
        ..._text('distributionChannel', a.distributionChannel),
        ..._text('division', a.division),
        ..._text('customerGroup', a.customerGroup),
        ..._text('salesOffice', a.salesOffice),
        ..._text('shippingCondition', a.shippingCondition),
        ..._text('paymentTerms', a.paymentTerms),
        ..._text('salesEmployee', a.salesEmployee),
      };

  static DataMap _suppliers(DepotDraftSuppliers s) => {
        if (s.primary case final p?) 'primary': _supplier(p),
        if (s.secondary case final p?) 'secondary': _supplier(p),
        if (s.tertiary case final p?) 'tertiary': _supplier(p),
      };

  static DataMap _supplier(DepotDraftSupplier s) =>
      {'type': s.type.apiValue, 'code': s.code};

  /// `{key: trimmed}` for non-blank text, `{}` otherwise.
  static DataMap _text(String key, String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? const {} : {key: text};
  }
}
