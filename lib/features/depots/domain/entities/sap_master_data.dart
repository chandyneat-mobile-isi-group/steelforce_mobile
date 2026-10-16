import 'package:steelforce/features/depots/domain/entities/sap_option.dart';

// -----------------------------------------------------------------------------
// Master data. Replace the hard-coded lists with a cached /masterdata call once
// the backend exposes it — the shape (SapOption) stays the same.
// -----------------------------------------------------------------------------
class SapMasterData {
  /// Depot groupings — the offline fallback for the ERP's `PartnerGroup`
  /// catalogue.
  ///
  /// `Z003` is **Group Member** (an intercompany depot), not "One-time
  /// Depot" as this list previously claimed. The label is the ERP's own, so
  /// the offline list and the loaded catalogue now name the same code the same
  /// way — a rep who picks `Z003` offline and sees it renamed after a sync has
  /// no way to tell whether their registration changed meaning.
  ///
  /// Deliberately only the depot subset. The server publishes 11 groupings
  /// including `ZBP1 Local Supplier` and `ZSL4 Employee`; those are filtered
  /// out by [SapReferenceOptions.partnerGroup] and must not be added here.
  static const List<SapOption> grouping = [
    SapOption('Z001', 'Local Depot', 'អតិថិជនក្នុងស្រុក'),
    SapOption('Z002', 'Export Depot', 'អតិថិជននាំចេញ'),
    SapOption('Z003', 'Group Member', 'សមាជិកក្រុម'),
  ];

  static const List<SapOption> title = [
    SapOption('0003', 'Company', 'ក្រុមហ៊ុន'),
    SapOption('0001', 'Ms.', 'កញ្ញា'),
    SapOption('0002', 'Mr.', 'លោក'),
  ];

  // The `city`, `districtByCity` and `postalCodeByDistrict` tables that used to
  // sit here are gone. They held five provinces, one province's districts and
  // the superseded five-digit Phnom Penh postal codes — so a rep in Kampot
  // could not enter their own district, and the postal code was keyed to a
  // district rather than to the commune that actually determines it.
  //
  // The full hierarchy (25 provinces, 203 districts, 1,646 communes, 14,372
  // villages) now lives in the shared geo_location feature, backed by the
  // bundled gazetteer. Use `GeoLocationSelector`; see
  // `docs/features/geo-location/README.md`.

  // ── Sales area ─────────────────────────────────────────────────────
  //
  // Previously not offered: `salesOrg` and `salesOffice` came from the rep's
  // session and `salesGroup` was the constant `010`, so a rep registering a
  // shop in Battambang filed it against Phnom Penh. All three are part of the
  // sales area SAP requires, and getting one wrong is not a validation error —
  // it is a depot routed to the wrong office.

  static const List<SapOption> salesOrg = [
    SapOption('0001', 'Phnom Penh (ISI)'),
    SapOption('0002', 'Building Solutions'),
    SapOption('0003', 'Battambang'),
    SapOption('0004', 'Sihanoukville'),
    SapOption('0005', 'Kampong Cham'),
    SapOption('0006', 'Kampong Thom'),
    SapOption('0007', 'Takeo'),
    SapOption('0008', 'Svay Rieng'),
    SapOption('0009', 'Siem Riep'),
    SapOption('0010', 'Kratie'),
    SapOption('0011', 'Pursat'),
    SapOption('0012', 'Banteaymeanchey'),
    SapOption('0013', 'Kampong Chhang'),
    SapOption('0014', 'Rorkar Korng'),
    SapOption('0015', 'Udong'),
    SapOption('0016', 'Svay Antor'),
    SapOption('0017', 'Kean Svay'),
    SapOption('0018', 'Tbong Khmum'),
    SapOption('0019', 'Phnom Penh (GVM)'),
    SapOption('0020', 'Export'),
    SapOption('0021', 'Export (GVM)'),
    SapOption('9999', 'Internal'),
  ];

  static const List<SapOption> salesOffice = [
    SapOption('0001', 'Phnom Penh'),
    SapOption('0002', 'Building Solutions'),
    SapOption('0003', 'Battambang'),
    SapOption('0004', 'Sihanoukville'),
    SapOption('0005', 'Kampong Cham'),
    SapOption('0006', 'Kampong Thom'),
    SapOption('0007', 'Takeo'),
    SapOption('0008', 'Svay Rieng'),
    SapOption('0009', 'Siem Riep'),
    SapOption('0010', 'Kratie'),
    SapOption('0011', 'Pursat'),
    SapOption('0012', 'Banteaymeanchey'),
    SapOption('0013', 'Kampong Chhang'),
    SapOption('0014', 'Rorkar Korng'),
    SapOption('0015', 'Udong'),
    SapOption('0016', 'Svay Antor'),
    SapOption('0017', 'Kean Svay'),
    SapOption('0018', 'Tbong Khmum'),
    SapOption('0019', 'Phnom Penh (GVM)'),
    SapOption('0020', 'Export'),
  ];

  static const List<SapOption> salesGroup = [
    SapOption('010', 'Channel Sales'),
    SapOption('020', 'Project Sales'),
    SapOption('030', 'Sales Showroom'),
    SapOption('040', 'Export Sales'),
    SapOption('050', 'Key Account Sales'),
    SapOption('060', 'Digital Sales'),
  ];

  static const List<SapOption> distributionChannel = [
    SapOption('10', 'End-User'),
    SapOption('20', 'Local Builder'),
    SapOption('30', 'Craftsman'),
    SapOption('40', 'PIPE Maker'),
    SapOption('50', 'Contractor'),
    SapOption('60', 'Developer'),
    SapOption('70', 'Distributor'),
    SapOption('80', 'Exporter'),
    SapOption('99', 'Internal'),
  ];

  static const List<SapOption> division = [
    SapOption('10', 'ISI Steel'),
    SapOption('20', 'Mekong Homes'),
    SapOption('30', 'Palm Truss'),
    SapOption('40', 'Galva Coil'),
    SapOption('99', 'Internal'),
  ];

  /// Replaces the old free-text "Shop Type" dropdown.
  static const List<SapOption> depotGroup = [
    SapOption('01', 'End-User', 'អ្នកប្រើប្រាស់ចុងក្រោយ'),
    SapOption('02', 'Local Builder'),
    SapOption('03', 'Craftsman'),
    SapOption('04', 'PIPE Maker'),
    SapOption('05', 'Contractor'),
    SapOption('06', 'Developer'),
    SapOption('07', 'Distributor', 'អ្នកចែកចាយ'),
    SapOption('08', 'Exporter'),
  ];

  /// Price group derived from depot group.
  ///
  /// **Corrected against the live catalogues.** The previous map emitted `12`,
  /// `13`, `14` and `15` — none of which exist in SAP's price groups (`11`,
  /// `21`, `31`, `41`, `51`, `52`, `53`, `61`, `71`). Every registration that
  /// derived one carried a price group the ERP would reject.
  ///
  /// The real relationship is by *name*, not by arithmetic: depot group
  /// `05 Contractor` pairs with price group `51 Contractor`. This map is the
  /// offline fallback; when the catalogues are loaded,
  /// `SapReferenceOptions.priceGroupFor` matches on the name instead, so a new
  /// pairing added in SAP works without an app release.
  ///
  /// `08 Exporter` is deliberately absent — SAP publishes no matching price
  /// group, and inventing one would be worse than leaving it unset.
  static const Map<String, String> priceGroupByDepotGroup = {
    '01': '11', // End-User
    '02': '21', // Local Builder
    '03': '31', // Craftsman
    '04': '41', // PIPE Maker
    '05': '51', // Contractor
    '06': '61', // Developer
    '07': '71', // Distributor
  };

  static const List<SapOption> priceGroup = [
    SapOption('11', 'End-User'),
    SapOption('21', 'Local Builder'),
    SapOption('31', 'Craftsman'),
    SapOption('41', 'PIPE Maker'),
    SapOption('51', 'Contractor'),
    SapOption('52', 'Key Account'),
    SapOption('53', 'ISI Group'),
    SapOption('61', 'Developer'),
    SapOption('71', 'Distributor'),
  ];

  static const List<SapOption> deliveryPriority = [
    SapOption('01', 'High'),
    SapOption('02', 'Normal'),
    SapOption('03', 'Low'),
  ];

  static const List<SapOption> shippingCondition = [
    SapOption('01', 'ISI Services'),
    SapOption('02', 'Depot Pickup'),
  ];

  static const List<SapOption> paymentTerm = [
    // Cash and cash-equivalent — no credit exposure.
    SapOption('TCIA', 'CIA-Cash in Advance'),
    SapOption('TCOD', 'COD-Cash on Delivery'),
    // Net terms.
    SapOption('T007', '7 days due net'),
    SapOption('T014', '14 day due net'),
    SapOption('T015', '15 days due net'),
    SapOption('T030', '30 days due net'),
    SapOption('T045', '45 days due net'),
    SapOption('T060', '60 days due net'),
    SapOption('T070', '70 days due net'),
    SapOption('T075', '75 days due net'),
    SapOption('T090', '90 days due net'),
    SapOption('T120', '120 days due net'),
    // Due on a day of the following month.
    SapOption('TN05', 'Due 05th next month'),
    SapOption('TN15', 'Due 15th next month'),
    SapOption('TN20', 'Due 20th next month'),
    SapOption('TN25', 'Due 25th next month'),
    SapOption('TN30', 'Due 30th next month'),
    SapOption('TN50', 'Due 50th next month'),
    SapOption('TN60', 'Due 60th next month'),
    // Letter of credit — export trade.
    SapOption('LCAS', 'LC At sight'),
    SapOption('LC30', 'LC after sight 30 days'),
    SapOption('LC45', 'LC after sight 45 days'),
    SapOption('LC60', 'LC after sight 60 days'),
    SapOption('LC90', 'LC after sight 90 days'),
    SapOption('BL30', 'LC after BL date 30days'),
    SapOption('BL45', 'LC after BL date 45days'),
    SapOption('BL60', 'LC after BL date 60days'),
    SapOption('BL90', 'LC after BL date 90days'),
  ];

  /// Payment terms that settle before or on delivery, so no credit is extended.
  ///
  /// The old rule was `code != 'T00'`, against a hard-coded list whose only
  /// cash term was `T00` — a code SAP does not publish. Every real term
  /// therefore looked like a credit sale, including cash on delivery.
  static const Set<String> cashPaymentTerms = {'TCIA', 'TCOD'};

  /// True when the term extends credit and so needs HQ approval.
  ///
  /// Unknown codes are treated as credit deliberately: a term this build has
  /// not seen is more safely routed through an approval it did not need than
  /// waved through as cash it was not.
  static bool paymentTermNeedsCreditApproval(String? code) =>
      code != null && code.isNotEmpty && !cashPaymentTerms.contains(code);

  static const List<SapOption> taxClass = [
    SapOption('0', 'Non VAT'),
    SapOption('1', 'VAT (Liable)'),
  ];

  /// `Language` — the depot's correspondence language.
  ///
  /// App-side codes, not SAP's. `sapLanguageKey` in the mapper converts them:
  /// SAP wants the single character `E` for English, which is why this cannot
  /// simply be sent through.
  static const List<SapOption> language = [
    SapOption('EN', 'English', 'អង់គ្លេស'),
    SapOption('KM', 'Khmer', 'ខ្មែរ'),
  ];

  static const List<SapOption> currency = [
    SapOption('USD', 'US Dollar'),
    SapOption('KHR', 'Riel'),
  ];

  static const List<SapOption> creditLimit = [
    SapOption('3000', r'$3,000'),
    SapOption('5000', r'$5,000'),
    SapOption('10000', r'$10,000'),
    SapOption('20000', r'$20,000'),
    SapOption('50000', r'$50,000'),
    SapOption('100000', r'$100,000'),
  ];

  const SapMasterData._();
}
