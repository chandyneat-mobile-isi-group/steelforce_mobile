import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/domain/entities/sap_bp_const.dart';
import 'package:steelforce/features/depots/domain/entities/sap_master_data.dart';

/// The fields the wizard fills in for the rep: sales-area defaults from the
/// session, the price group from the depot group, and the two search terms.
extension BpDepotDraftDerivations on BpDepotDraft {
  /// Keep the derived fields consistent whenever a driver field changes.
  /// Fills default sales area fields from the rep's session if not already set.
  void applyRepDefaults(RepSalesContext rep) {
    if (salesOrg == null || salesOrg!.isEmpty) {
      salesOrg = rep.salesOrganization.isNotEmpty
          ? rep.salesOrganization
          : SapBpConst.salesOrg;
    }
    if (salesOffice == null || salesOffice!.isEmpty) {
      salesOffice =
          rep.salesOffice.isNotEmpty ? rep.salesOffice : SapBpConst.salesOffice;
    }
    if (salesGroupCode == null || salesGroupCode!.isEmpty) {
      salesGroupCode = SapBpConst.salesGroup;
    }
  }

  /// [priceGroupResolver] resolves the price group from the depot group,
  /// normally `SapReferenceOptions.priceGroupFor`, which matches the two ERP
  /// catalogues by name.
  ///
  /// Optional so the model stays usable without the catalogues loaded; when it
  /// is absent the built-in pairing is used instead.
  void applyDerivations({String? Function(String?)? priceGroupResolver}) {
    if (salesOrg == null || salesOrg!.isEmpty) {
      salesOrg = SapBpConst.salesOrg;
    }
    if (salesOffice == null || salesOffice!.isEmpty) {
      salesOffice = SapBpConst.salesOffice;
    }
    if (salesGroupCode == null || salesGroupCode!.isEmpty) {
      salesGroupCode = SapBpConst.salesGroup;
    }
    // The postal code is NOT derived here any more. It comes from the selected
    // commune, via the gazetteer (`GeoAddress.postalCode`), and the selector
    // writes it onto the draft.
    //
    // The old rule — fill an empty postal code from a per-district table —
    // has to stay gone rather than act as a fallback. That table holds the
    // superseded five-digit Phnom Penh codes, and the case where it would now
    // fire is precisely the case it gets wrong: `postalCode` is empty exactly
    // when the chosen commune is one of the 99 Cambodia Post does not cover,
    // and filling it from the *district* would ship a code for a different
    // place. `validateStep` blocks submission instead, and the rep types the
    // real code — never a silently wrong one (§10).
    // A hand-picked price group wins over the derived one. The pairing is
    // derived because it is usually mechanical, not because the rep is never
    // right — and the reference payload pairs depot group `01` with price
    // group `21` where both catalogues pair it with `11`, so the two do
    // disagree in practice.
    if (depotGroup != null && !priceGroupOverridden) {
      // The resolver matches the ERP's own depot-group and price-group
      // catalogues by name, so a pairing added in SAP works without an app
      // release. The built-in map is the offline fallback.
      priceGroup = priceGroupResolver?.call(depotGroup) ??
          SapMasterData.priceGroupByDepotGroup[depotGroup!];
    }
    // `SearchTerm1` is the place, matching the sample payload. The city name
    // comes from the gazetteer when a commune has been picked; before that
    // there is nothing to derive from and the field stays empty rather than
    // borrowing the shop name, which belongs in `SearchTerm2`.
    if (searchTerm.isEmpty) {
      final city = geoAddress?.province?.name.resolve('en').trim() ?? '';
      if (city.isNotEmpty) searchTerm = city.toUpperCase();
    }

    // `SearchTerm2` is the shop shorthand: brand plus district, which is how
    // a rep or a phone operator actually refers to an outlet. Derived only
    // while untouched, so a rep who types their own is never overwritten by a
    // later district change.
    if (searchTerm2.isEmpty && nameEn.isNotEmpty) {
      final brand = nameEn.split(RegExp(r'\s+')).first.toUpperCase();
      final district = geoAddress?.district?.name.resolve('en').trim() ?? '';
      searchTerm2 =
          district.isEmpty ? brand : '$brand ${district.toUpperCase()}';
    }
  }
}
