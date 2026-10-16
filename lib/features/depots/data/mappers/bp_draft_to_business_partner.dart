// =============================================================================
// bp_draft_to_business_partner.dart
//
// Turns the wizard's [BpDepotDraft] into a [BusinessPartnerRequest].
//
// This is where the two vocabularies meet, and the differences are not
// cosmetic. Three of them change what SAP receives:
//
//  1. `City` and `District` are now *names*, not gazetteer codes. The old
//     payload sent `'city': cityCode`; the sample sends `"City": "Phnom Penh"`
//     and `"District": "Sen Sok"`. SAP's `ADRC-CITY1`/`CITY2` are free text
//     and the codes are ours, not SAP's — sending `1201` would put the code in
//     the address line a delivery driver reads. Names come from the gazetteer
//     via `GeoAddress`; the code is the fallback so an older draft still
//     submits rather than submitting blank.
//
//  2. `Language` is a SAP language key (`E`), not the app locale (`EN`).
//     `SapBpConst.defaultLanguage` is `'EN'`, which this endpoint would reject.
//
//  3. There are two search terms. The draft has one field, so `SearchTerm1`
//     is derived from the city — matching the sample, where it is the place
//     and `SearchTerm2` is the shop shorthand.
//
// The contact person's name and role travel together in `CoName` as
// `Name-Role` (see `BpDepotDraft.contactCoName`).
//
// Fields the draft carries that this endpoint has nowhere to put — `vatTin`,
// `faxNumber`, `remark`, `title`, `attachments` — are deliberately not
// smuggled in as extra keys. See the wiring notes for where they have to go
// instead.
// =============================================================================

import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/domain/entities/sap_bp_const.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';

/// Wire-side constants that differ from [SapBpConst].
///
/// Kept separate rather than corrected in place, because [SapBpConst] is also
/// read by the form and the draft store and changing a value there would
/// rewrite the meaning of drafts already saved on devices.
class SapBpWireConst {
  /// `CreditControlArea`. **The sample payload sends `0001`;
  /// `SapBpConst.creditControlArea` is `ISI`.** One of the two is wrong and it
  /// is not decidable from the app — confirm with the SAP team and delete the
  /// loser. `0001` is used here on the grounds that the payload is the newer
  /// artefact.
  static const String creditControlArea = '0001';

  /// `SalesGroup` fallback, matching [SapBpConst.salesGroup].
  static const String salesGroup = SapBpConst.salesGroup;

  /// `PartnerCounter` — first partner of this function.
  static const String partnerCounter = '001';

  /// SAP `SORT1`/`SORT2` are 20 characters.
  static const int searchTermMaxLength = 20;

  /// SAP `NAME1`..`NAME4` are 40 characters. The form already blocks a longer
  /// `nameEn`, but `name2`, `name3` and `coName` are unvalidated and a Khmer
  /// name that is 41 characters would be truncated by SAP silently.
  static const int nameMaxLength = 40;

  const SapBpWireConst._();
}

/// Maps the app's locale to a SAP language key.
///
/// The sample sends `E`. SAP's single-character keys are a legacy set that
/// covers the original languages only, so Khmer travels as the two-character
/// ISO key. Anything unrecognised falls back to `E` rather than being passed
/// through: a language key SAP does not know fails the whole registration,
/// and English correspondence is recoverable where a rejected shop is not.
String sapLanguageKey(String? appLanguage) {
  final value = (appLanguage ?? '').trim().toUpperCase();
  return switch (value) {
    'E' || 'EN' || 'ENG' || 'EN-US' => 'E',
    'KM' || 'KH' || 'KHM' || 'KM-KH' => 'KM',
    _ => 'E',
  };
}

extension BpDepotDraftWireX on BpDepotDraft {
  /// Builds the registration payload.
  ///
  /// [rep] supplies the sales area the rep did not override and their
  /// personnel number. [priceGroupResolver] is forwarded to
  /// [applyDerivations] so the loaded ERP catalogues win over the built-in
  /// pairing when they are available.
  ///
  /// [depotNumber] overrides whatever the draft carries. Leave it null for
  /// the normal case — a new registration has no number, and a draft opened as
  /// a correction already holds the right one. Pass `''` only to deliberately
  /// force a create from a draft that has a number.
  BusinessPartnerRequest toBusinessPartnerRequest({
    required RepSalesContext rep,
    String? Function(String?)? priceGroupResolver,
    String? depotNumber,
    bool submitToSap = true,
  }) {
    // Recompute price group and search term before reading them; a rep can
    // change the depot group on step 4 and submit without the derivation
    // having run.
    applyDerivations(priceGroupResolver: priceGroupResolver);

    final cityName = _cityName;

    return BusinessPartnerRequest(
      commit: true,
      // The argument wins so a caller can force a create, but a draft that was
      // opened as a correction carries its own number and must keep it —
      // dropping it would turn an edit into a duplicate partner.
      depotNumber: (depotNumber ?? this.depotNumber).trim(),

      // --- BP header ------------------------------------------------------
      partnerCategory: SapBpConst.partnerCategory,
      // `PartnerGroup` and `AccountGroup` both carry the grouping (`Z001`).
      // They are separate keys in SAP for a reason but the same value here,
      // matching the sample; if the two ever diverge this is the line to split.
      partnerGroup: grouping,
      bpRole: SapBpConst.bpRole,
      accountGroup: grouping,

      // --- Names ----------------------------------------------------------
      name1: _clampName(nameEn),
      name2: _clampName(name2),
      name3: _clampName(nameKh),
      // Who to ask for at the shop, as `Name-Role`: the endpoint has no
      // contact-person key, so SAP's c/o name carries it.
      coName: contactCoName,
      // Sample: SearchTerm1 is the place, SearchTerm2 the shop shorthand.
      // Both are rep-editable and both are derived when left blank, so read
      // the draft first and fall back to the city only if it is still empty.
      searchTerm1: _clampSearch(searchTerm.isEmpty ? cityName : searchTerm),
      searchTerm2: _clampSearch(searchTerm2),

      // --- Address --------------------------------------------------------
      district: _districtName,
      country: SapBpConst.country,
      // Rep-invisible today, but read from the draft rather than the constant
      // so a reference catalogue can correct it without a mapper change.
      region: regionCode.isEmpty ? SapBpConst.region : regionCode,
      city: cityName,
      // Folds village and commune into the street line, which is the only
      // field that reaches SAP for those two levels.
      street: sapStreetLine,
      houseNo: houseNumber.trim(),
      postalCode: postalCode.trim(),
      latitude: _coordinate(geoFix?.latitude),
      longitude: _coordinate(geoFix?.longitude),

      // --- Communication --------------------------------------------------
      language: sapLanguageKey(language),
      telephone: effectiveTelephone.trim(),
      mobilePhone: mobilePhone.trim(),

      // --- Sales area & terms ---------------------------------------------
      // The rep's own selection wins, with the session sales area as fallback.
      salesOrg: salesOrg ?? rep.salesOrganization,
      distributionChannel: distributionChannel ?? '',
      division: divisionCode ?? '',
      depotGroup: depotGroup ?? '',
      salesOffice: salesOffice ?? rep.salesOffice,
      salesGroup: salesGroupCode ?? SapBpWireConst.salesGroup,
      // Left blank when the depot group has no published pairing (`08
      // Exporter`). Inventing one would ship a price group the ERP rejects.
      priceGroup: priceGroup ?? '',
      pricingProc: SapBpConst.pricingProcedure,
      deliveryPriority: deliveryPriority ?? '',
      shippingCondition: shippingCondition ?? '',
      currency: currency.isEmpty ? rep.defaultCurrency : currency,
      paymentTerms: paymentTerm ?? '',
      // Not on the form: always the default, even for a draft saved before
      // the field was removed.
      creditLimit: SapBpConst.creditLimit,
      creditControlArea: SapBpWireConst.creditControlArea,

      // --- Tax -------------------------------------------------------------
      taxCountry: SapBpConst.departureCountry,
      taxType: SapBpConst.taxCategory,
      taxClass: taxClass ?? '0',

      // --- Partner function ------------------------------------------------
      partnerFunction: SapBpConst.partnerFunction,
      partnerCounter: SapBpWireConst.partnerCounter,
      personnelNumber: _digitsOnly(rep.salesEmployeeId),

      // --- Blocks ----------------------------------------------------------
      // Always blank from the app. A registration never arrives blocked; HQ
      // sets a block in SAP after the fact. Sent as empty strings rather than
      // omitted so a correction call clears a block instead of leaving it.
      orderBlock: '',
      salesBlock: '',
      blockFlag: '',

      submitToSap: submitToSap,
    );
  }

  /// City / province name for `City` and `SearchTerm1`.
  ///
  /// Prefers the gazetteer's English name; falls back to the stored code so a
  /// draft saved before the gazetteer selector existed still submits.
  String get _cityName {
    final province = geoAddress?.province;
    if (province != null) return province.name.resolve('en').trim();
    return (cityCode ?? '').trim();
  }

  /// District name for `District`. Same fallback reasoning as [_cityName].
  String get _districtName {
    final district = geoAddress?.district;
    if (district != null) return district.name.resolve('en').trim();
    return (districtCode ?? '').trim();
  }

  String _clampName(String value) {
    final v = value.trim();
    return v.length <= SapBpWireConst.nameMaxLength
        ? v
        : v.substring(0, SapBpWireConst.nameMaxLength).trimRight();
  }

  /// Search terms are upper-cased because SAP's `SORT1` search is
  /// case-sensitive on the stored value; a mixed-case term is findable only by
  /// someone who types it the same way.
  String _clampSearch(String value) {
    final v = value.trim().toUpperCase();
    return v.length <= SapBpWireConst.searchTermMaxLength
        ? v
        : v.substring(0, SapBpWireConst.searchTermMaxLength).trimRight();
  }
}

/// Coordinates travel as strings, at the contract's four decimal places.
///
/// Four decimals is roughly 11 metres, which does not reliably distinguish one
/// shopfront from its neighbour — six would be better for actually finding the
/// door. It is four anyway because the documented body sends four, the SAP
/// geo fields have a fixed width, and a wider string than the field accepts is
/// the kind of difference that gets a record accepted by the middleware and
/// dropped on the SAP push.
///
/// If the field turns out to be `CHAR(11)` or wider, raise this to 6 — the
/// extra precision is worth having and nothing else depends on the width.
String _coordinate(double? value) =>
    value == null ? '' : value.toStringAsFixed(4);

/// Strips everything but digits.
///
/// SAP's `PERNR` is a numeric field. A non-numeric personnel number — the
/// literal `'mobile'` that the placeholder [RepSalesContext] supplies — is
/// accepted by the middleware and then fails on the SAP push, which is exactly
/// the "submitted to the backend but never stored in SAP" symptom: the record
/// exists locally, the ERP never gets it, and nothing in the mobile log says
/// why.
///
/// Returns empty rather than a substitute when there is nothing numeric left,
/// so [BusinessPartnerRequest.isRegisterable] refuses the submit instead of
/// sending a value SAP will silently discard.
String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');
