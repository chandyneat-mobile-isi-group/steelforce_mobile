// =============================================================================
// bp_depot_form_data.dart
//
// SAP BP (Depot) creation — mobile capture model.
// Pure Dart (no Flutter imports) so it can be unit-tested and reused by the
// bloc, the repository and the offline draft store.
//
// Source of truth: BP_Creation_Field_SAP.xlsx
//   Create Organization (BP) > Extend Depot > FI Depot
//
// Field ownership legend:
//   REP    = sales rep types / picks it on the phone
//   CONST  = hard-coded at frontend (never shown, never editable)
//   DERIVE = computed from GPS, session (rep's sales area) or another field
//   SAP    = comes back from SAP after creation (read-only in the app)
// =============================================================================

import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';

import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/data/models/depot_registration_type.dart';
import 'package:steelforce/features/depots/data/models/depot_sales_survey.dart';

export 'package:steelforce/features/depots/data/models/depot_registration_type.dart';
export 'package:steelforce/features/depots/data/models/depot_sales_survey.dart';

/// The seven capture steps of the "Add Depot" bottom sheet.
enum BpFormStep {
  identity, // 1. Who is the depot          (BP header + names)
  address, // 2. Where are they                (standard address + GPS)
  contact, // 3. How do we reach them          (phones + contact person)
  salesTerms, // 4. How do we sell to them     (sales area + billing/tax)
  salesPerformance, // 5. What they sell today (field survey Q1–Q4)
  documents, // 6. Proof                       (photos)
  review, // 7. Review                         (submit)
}

extension BpFormStepX on BpFormStep {
  int get number => index + 1;

  String get titleKey => switch (this) {
        BpFormStep.identity => 'add_depot.steps.identity',
        BpFormStep.address => 'add_depot.steps.address',
        BpFormStep.contact => 'add_depot.steps.contact',
        BpFormStep.salesTerms => 'add_depot.steps.sales_terms',
        BpFormStep.salesPerformance => 'add_depot.steps.sales_performance',
        BpFormStep.documents => 'add_depot.steps.documents',
        BpFormStep.review => 'add_depot.review',
      };
}

/// A SAP key/description pair as shown in a dropdown ("Z001 - Local Depot").
class SapOption {
  final String code;
  final String labelEn;
  final String? labelKh;

  const SapOption(this.code, this.labelEn, [this.labelKh]);

  String get display => '$code - $labelEn';

  @override
  String toString() => display;
}

// -----------------------------------------------------------------------------
// CONST — hard-coded at frontend. Never rendered as an input.
// -----------------------------------------------------------------------------
class SapBpConst {
  static const String partnerCategory = '2'; // Organization
  static const String bpRole = 'ZFLCU1'; // Depot
  static const String country = 'KH'; // Cambodia
  static const String departureCountry = 'KH';
  static const String region = 'R01'; // Central Area
  static const String timeZone = 'UTC+7';
  static const String salesOrg = '0001'; // Phnom Penh (ISI)
  static const String salesOffice = '0001'; // Phnom Penh
  static const String salesGroup = '010'; // Channel Sales
  static const String pricingProcedure = '1'; // Standard
  static const String taxCategory = 'MWST';
  static const String partnerFunction = 'VE'; // Sales Employee
  static const String creditControlArea = 'ISI';
  static const String companyCode = 'ISI';
  static const String defaultLanguage = 'EN';

  /// `T014` — 14 day due net. Business default for every new depot; the rep
  /// can still change it under "Adjust defaults".
  static const String defaultPaymentTerm = 'T014';

  /// Sent on every registration. Reps no longer pick a credit limit: HQ sets
  /// it in SAP after approval.
  static const String creditLimit = '0.00';

  /// The contact person's role on step 3. The English label is what SAP
  /// receives, inside `CoName` (see [BpDepotDraft.contactCoName]).
  static const List<SapOption> contactRoles = [
    SapOption('owner', 'Owner'),
    SapOption('manager', 'Manager'),
    SapOption('buyer', 'Buyer'),
    SapOption('accountant', 'Accountant'),
  ];

  /// SAP `NAME_CO` is 40 characters.
  static const int coNameMaxLength = 40;

  const SapBpConst._();
}

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
  // `docs/feature/geo-location/README.md`.

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

/// Sales-area context of the logged-in rep. Injected from the auth/session
/// layer — the rep never types these.
class RepSalesContext {
  final String salesOrganization; // 0001 - PhnomPenh ISI
  final String salesOrganizationName;
  final String salesOffice; // 0001 - Phnom Penh
  final String salesOfficeName;
  final String salesEmployeeId; // 107576
  final String salesEmployeeName; // Mengchou CHORN
  final String defaultCurrency; // USD

  const RepSalesContext({
    required this.salesOrganization,
    required this.salesOrganizationName,
    required this.salesOffice,
    required this.salesOfficeName,
    required this.salesEmployeeId,
    required this.salesEmployeeName,
    this.defaultCurrency = 'USD',
  });
}

/// A GPS fix captured on site.
class GeoFix {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime capturedAt;

  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
  });

  /// Rough Cambodia bounding box — rejects an emulator fix or a stale
  /// last-known location from another country.
  bool get isInsideCambodia =>
      latitude >= 9.9 &&
      latitude <= 14.7 &&
      longitude >= 102.3 &&
      longitude <= 107.7;

  String get display =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// One captured document / photo, held on the device until the depot exists.
///
/// Evidence cannot be uploaded during the wizard: the documents endpoint is
/// addressed by depot id, and the depot is not created until submit. So
/// the rep photographs the shop while standing in it, and the files go up once
/// the registration has returned an id
/// (`docs/feature/depot/mobile/depot-documents.md` §Flow).
class BpAttachment {
  final String
      kind; // outlet_front | outlet_inside | id_card | patent_tax | vat_cert
  final String localPath;
  final String? remoteUrl;
  final bool isUploaded;
  final bool isUploading;
  final String? uploadError;

  /// When the photograph was taken.
  ///
  /// Stamped here rather than at upload because the upload happens after
  /// submit and may be minutes or hours later; dating the evidence to when the
  /// connection came back would misrepresent the visit.
  final DateTime capturedAt;

  BpAttachment({
    required this.kind,
    required this.localPath,
    this.remoteUrl,
    this.isUploaded = false,
    this.isUploading = false,
    this.uploadError,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now().toUtc();

  BpAttachment copyWith({
    String? kind,
    String? localPath,
    String? remoteUrl,
    bool? isUploaded,
    bool? isUploading,
    String? uploadError,
    DateTime? capturedAt,
  }) =>
      BpAttachment(
        kind: kind ?? this.kind,
        localPath: localPath ?? this.localPath,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        isUploaded: isUploaded ?? this.isUploaded,
        isUploading: isUploading ?? this.isUploading,
        uploadError: uploadError,
        capturedAt: capturedAt ?? this.capturedAt,
      );

  /// The form's local slot names, paired with the API's codes.
  ///
  /// The two vocabularies are kept apart on purpose: the tile keys are UI
  /// identifiers with their own history (`outlet_front`), and the codes are the
  /// wire contract. Renaming either without the other would silently drop a
  /// photograph, so the pairing lives in exactly one place.
  static const Map<String, DepotDocumentType> kindToDocumentType = {
    'outlet_front': DepotDocumentType.storefront,
    'outlet_inside': DepotDocumentType.insideStore,
    'id_card': DepotDocumentType.idCard,
    'patent_tax': DepotDocumentType.patentTax,
    'vat_cert': DepotDocumentType.vatCertificate,
  };

  /// The API slot this attachment belongs in, or null for an unrecognised kind.
  DepotDocumentType? get documentType => kindToDocumentType[kind];

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'local_path': localPath,
        if (remoteUrl != null) 'url': remoteUrl,
        'is_uploaded': isUploaded,
      };
}

// =============================================================================
// The draft the rep builds up across the five steps.
// =============================================================================
class BpDepotDraft {
  // --- Step 1: Identity -------------------------------------------------
  /// Depot or Non-BP depot — sent as `depotType` (`DEPOT` / `NON_DEPOT`).
  DepotRegistrationType registrationType;

  /// A Non-BP depot's supplying depots, as SAP customer numbers: the
  /// request's `depots`, 1-20. Unused for a depot.
  List<String> supplyingDepots;

  /// Display names for [supplyingDepots], by code. Local only — never sent.
  Map<String, String> supplyingDepotNames;
  String grouping; // REP   Grouping            (Z001)
  String title; // REP   Title               (0003)
  String nameEn; // REP   Name 1 (EN)        *
  String nameKh; // REP   Name 3 (KH)        *
  String name2; // REP   Name 2              (optional)
  /// `SearchTerm1` on the wire. Holds the *place* — the sample payload sends
  /// `PHNOM PENH` here and the shop shorthand in `SearchTerm2`.
  ///
  /// Left as `searchTerm` rather than renamed to `searchTerm1`, because the
  /// name is persisted in locally saved drafts and in `applyServerFields`; a
  /// rename would strand every draft already on a device.
  String searchTerm; // REP   Search Term 1        (optional, auto-derived)

  /// `SearchTerm2`. The shop shorthand a rep would say out loud — the sample
  /// sends `BAYON STEEL SENSOK`, i.e. brand plus district.
  ///
  /// A second field rather than a longer first one: SAP's `SORT1` and `SORT2`
  /// are 20 characters each and are indexed separately, so a single 40-char
  /// term would be truncated to 20 and the rest lost silently.
  String searchTerm2; // REP   Search Term 2        (optional, auto-derived)
  /// Legacy: the rep no longer types a c/o name. Kept so drafts saved before
  /// still load; `CoName` is now [contactCoName].
  String coName;

  /// `DepotNumber`. Empty for a new registration.
  ///
  /// Set only when the call is correcting or extending a partner SAP already
  /// holds. Carried on the draft rather than passed at submit so a resumed
  /// correction does not silently become a create.
  String depotNumber;

  /// The id this form is sent under to `POST /api/v1/depot-drafts`.
  ///
  /// Minted once, saved with the form **before** the first send, and reused on
  /// every resend: the server answers a resend of the same id and content
  /// with the draft it already saved, so a lost answer never becomes a second
  /// depot.
  String? clientDraftId;

  /// Platform depot id once created on the backend.
  String? serverDepotId;
  bool isPendingHqApproval = false;

  bool get isDepotCreatedOnServer =>
      serverDepotId != null && serverDepotId!.isNotEmpty;

  // --- Step 2: Address --------------------------------------------------
  String street; // REP   Street / House Number
  String houseNumber; // REP
  String? cityCode; // REP   City / Province     *
  String? districtCode; // REP   District            *
  String? communeCode; // REP   Commune             *
  String? villageCode; // REP   Village             (optional)
  String postalCode; // DERIVE+REP Postal Code    *
  GeoFix? geoFix; // REP   Latitude / Longitude *
  String language; // REP   Language            (default EN)
  GeoAddress? geoAddress; // Domain gazetteer address

  /// `Region`. SAP's region key, not the gazetteer province.
  ///
  /// Still a constant default (`R01`) because SAP publishes no region
  /// catalogue this app can read, and the 25 provinces do not map onto it
  /// one-to-one. It is a field rather than a hard-coded literal so the value
  /// can be corrected from a reference catalogue without touching the mapper.
  String regionCode;

  // --- Step 3: Contact --------------------------------------------------
  String mobilePhone; // REP   Mobile Phone        *
  String telephone; // REP   Telephone           * (may mirror mobile)
  bool telephoneSameAsMobile;
  String faxNumber; // REP   Fax Number          (optional)
  String contactPersonName; // REP   (app CRM, sent as BP contact person)
  String? contactPersonRole;

  /// The contact person as the platform's own contact record.
  ///
  /// The three fields the rep fills on step 3 describe **one person**, but the
  /// draft stores them apart: a name, a role, and a phone that is also the
  /// depot's `MobilePhone`. Pairing them here rather than at each call site is
  /// the point — a caller that rebuilt the triple by hand could pair the role
  /// with the landline, or send a name with no number, and nothing would say
  /// so.
  ///
  /// `phone` is [mobilePhone] deliberately: step 3 collects exactly one mobile
  /// number and it is the number for this person. [telephone] is the shop's
  /// landline — it may merely mirror the mobile via
  /// [telephoneSameAsMobile] — so it is the wrong number to put on a person.
  ///
  /// Primary because the form captures one contact and one only. The backend
  /// demotes any previous primary rather than rejecting a second, so this is
  /// safe to send on an update too.
  ///
  /// Empty when no name was entered — never a contact with a blank name. An
  /// empty list must also never be *sent* on an update: `[]` means "remove
  /// every contact" (`docs/feature/depot/mobile/edit-depot.md`).
  List<DepotContactDraft> get contacts {
    final name = contactPersonName.trim();
    if (name.isEmpty) return const [];
    final role = contactPersonRole?.trim();
    return [
      DepotContactDraft(
        name: name,
        phone: mobilePhone.trim(),
        position: (role == null || role.isEmpty) ? null : role,
        isPrimary: true,
      ),
    ];
  }

  /// `CoName` on the registration: the contact person as `Name-Role`, e.g.
  /// `Sok Dara-Owner`.
  ///
  /// The business-partner endpoint has no contact-person key, so SAP's c/o
  /// name carries who to ask for at the shop. The role goes as its English
  /// label (SAP data is English), and the name alone when no role is picked.
  /// Over 40 characters the **name** is shortened, so the role survives SAP's
  /// limit instead of being cut off. Empty when no name was entered.
  String get contactCoName {
    final name = contactPersonName.trim();
    if (name.isEmpty) return '';
    final code = contactPersonRole?.trim();
    final role = SapBpConst.contactRoles
            .where((r) => r.code == code)
            .firstOrNull
            ?.labelEn ??
        (code ?? '');
    final suffix = role.isEmpty ? '' : '-$role';
    final room = SapBpConst.coNameMaxLength - suffix.length;
    final shortName =
        name.length <= room ? name : name.substring(0, room).trimRight();
    return '$shortName$suffix';
  }

  // --- Step 4: Sales & billing terms ------------------------------------
  //
  // The sales area (salesOrg + distributionChannel + division) is one of the
  // five field groups a record must carry to be registerable in SAP at all —
  // without it the push is marked `Rejected` without SAP even being called
  // (`docs/feature/depot/mobile/create-depot.md` §Path B).
  String? salesOrg; // REP   Sales Organization   *
  String? salesOffice; // REP   Sales Office      *
  String? salesGroupCode; // REP   Sales Group     *
  String? distributionChannel; // REP   Distribution Channel *
  String? divisionCode; // REP   Division             *
  String? depotGroup; // REP   Depot Group       *
  String? priceGroup; // DERIVE+REP Price Group      *

  /// True once the rep has chosen a price group by hand.
  ///
  /// Needed because [applyDerivations] runs on every edit: without this, a
  /// manual pick is silently overwritten the next time the rep touches any
  /// field, which reads as the dropdown refusing to hold its value.
  bool priceGroupOverridden = false;
  String? deliveryPriority; // REP   Delivery Priority    *
  String? shippingCondition; // REP   Shipping Condition   *
  String? paymentTerm; // REP   Payment Term         *
  String? taxClass; // REP   Tax Class            *
  String vatTin; // REP   (required when taxClass == '1')
  String currency; // DERIVE Currency             *
  double? creditLimit; // REP   Credit Limit (USD)

  // --- Step 5: Sales & performance --------------------------------------
  /// Local only: the request has no field for the survey yet.
  final DepotSalesSurvey salesSurvey;

  // --- Step 6: Documents ------------------------------------------------
  final List<BpAttachment> attachments;
  String remark;

  BpDepotDraft({
    this.registrationType = DepotRegistrationType.depot,
    List<String>? supplyingDepots,
    Map<String, String>? supplyingDepotNames,
    this.grouping = 'Z001',
    this.title = '0003',
    this.nameEn = '',
    this.nameKh = '',
    this.name2 = '',
    this.searchTerm = '',
    this.searchTerm2 = '',
    this.coName = '',
    this.depotNumber = '',
    this.street = '',
    this.houseNumber = '',
    this.cityCode,
    this.districtCode,
    this.communeCode,
    this.villageCode,
    this.postalCode = '',
    this.geoFix,
    this.language = SapBpConst.defaultLanguage,
    this.geoAddress,
    this.regionCode = SapBpConst.region,
    this.mobilePhone = '',
    this.telephone = '',
    this.telephoneSameAsMobile = true,
    this.faxNumber = '',
    this.contactPersonName = '',
    this.contactPersonRole,
    this.salesOrg = SapBpConst.salesOrg,
    this.salesOffice = SapBpConst.salesOffice,
    this.salesGroupCode = SapBpConst.salesGroup,
    this.distributionChannel = '10',
    this.divisionCode = '10',
    this.depotGroup,
    this.priceGroup,
    this.deliveryPriority = '01',
    this.shippingCondition = '01',
    this.paymentTerm = SapBpConst.defaultPaymentTerm,
    this.taxClass = '0',
    this.vatTin = '',
    this.currency = 'USD',
    this.creditLimit,
    this.serverDepotId,
    this.isPendingHqApproval = false,
    DepotSalesSurvey? salesSurvey,
    List<BpAttachment>? attachments,
    this.remark = '',
  })  : supplyingDepots = supplyingDepots ?? <String>[],
        supplyingDepotNames = supplyingDepotNames ?? <String, String>{},
        salesSurvey = salesSurvey ?? DepotSalesSurvey(),
        attachments = attachments ?? <BpAttachment>[];

  /// Applies the server-owned draft returned by `POST draft` and `POST update`.
  /// The API field names are deliberately kept at the boundary; the form keeps
  /// its more readable Flutter names.
  void applyServerFields(Map<String, dynamic> fields) {
    String stringValue(String key, [String fallback = '']) {
      final value = fields[key];
      return value == null ? fallback : value.toString();
    }

    String? nullableString(String key, [String? fallback]) {
      final value = fields[key];
      if (value == null || value.toString().isEmpty) return fallback;
      return value.toString();
    }

    grouping =
        stringValue('accountGroup', stringValue('partnerGroup', grouping));
    title = stringValue('title', title);
    nameEn = stringValue('name1', nameEn);
    name2 = stringValue('name2', name2);
    nameKh = stringValue('name3', nameKh);
    searchTerm = stringValue('searchTerm1', searchTerm);
    searchTerm2 = stringValue('searchTerm2', searchTerm2);
    coName = stringValue('coName', coName);
    depotNumber = stringValue('depotNumber', depotNumber);
    street = stringValue('street', street);
    houseNumber = stringValue('houseNo', houseNumber);
    if (fields.containsKey('city')) cityCode = nullableString('city', cityCode);
    if (fields.containsKey('district')) {
      districtCode = nullableString('district', districtCode);
    }
    if (fields.containsKey('commune')) {
      communeCode = nullableString('commune', communeCode);
    } else if (fields.containsKey('communeCode')) {
      communeCode = nullableString('communeCode', communeCode);
    }
    if (fields.containsKey('village')) {
      villageCode = nullableString('village', villageCode);
    } else if (fields.containsKey('villageCode')) {
      villageCode = nullableString('villageCode', villageCode);
    }
    postalCode = stringValue('postalCode', postalCode);
    regionCode = stringValue('region', regionCode);
    language = stringValue('language', language);
    mobilePhone = stringValue('mobilePhone', mobilePhone);
    telephone = stringValue('telephone', telephone);
    telephoneSameAsMobile = telephone.isEmpty || telephone == mobilePhone;
    faxNumber = stringValue('faxNumber', faxNumber);
    contactPersonName = stringValue('contactPersonName', contactPersonName);
    if (fields.containsKey('contactPersonRole')) {
      contactPersonRole =
          nullableString('contactPersonRole', contactPersonRole);
    }
    if (fields.containsKey('salesOrg')) {
      salesOrg = nullableString('salesOrg', salesOrg);
    }
    if (fields.containsKey('salesOffice')) {
      salesOffice = nullableString('salesOffice', salesOffice);
    }
    if (fields.containsKey('salesGroup')) {
      salesGroupCode = nullableString('salesGroup', salesGroupCode);
    }
    if (fields.containsKey('distributionChannel')) {
      distributionChannel =
          nullableString('distributionChannel', distributionChannel);
    }
    if (fields.containsKey('division')) {
      divisionCode = nullableString('division', divisionCode);
    }
    if (fields.containsKey('depotGroup')) {
      depotGroup = nullableString('depotGroup', depotGroup);
    }
    if (fields.containsKey('priceGroup')) {
      priceGroup = nullableString('priceGroup', priceGroup);
    }
    if (fields.containsKey('deliveryPriority')) {
      deliveryPriority = nullableString('deliveryPriority', deliveryPriority);
    }
    if (fields.containsKey('shippingCondition')) {
      shippingCondition =
          nullableString('shippingCondition', shippingCondition);
    }
    if (fields.containsKey('paymentTerms')) {
      paymentTerm = nullableString('paymentTerms', paymentTerm);
    }
    if (fields.containsKey('taxClass')) {
      taxClass = nullableString('taxClass', taxClass);
    }
    vatTin = stringValue('vatTin', vatTin);
    currency = stringValue('currency', currency);
    remark = stringValue('remark', remark);

    if (fields.containsKey('creditLimit')) {
      final rawCreditLimit = fields['creditLimit'];
      if (rawCreditLimit is num) {
        creditLimit = rawCreditLimit.toDouble();
      } else if (rawCreditLimit is String && rawCreditLimit.isNotEmpty) {
        creditLimit = double.tryParse(rawCreditLimit);
      }
    }

    final latitude = fields['latitude'];
    final longitude = fields['longitude'];
    if (latitude is num && longitude is num) {
      geoFix = GeoFix(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        capturedAt: DateTime.now(),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Local draft persistence.
  //
  // Deliberately NOT the wire payload. The mapper drops everything SAP has no
  // field for — `vatTin`, the contact person, the remark, the photographs.
  // Persisting through it would mean a rep who resumed a saved form silently
  // lost the four fields the form had just made them fill in.
  //
  // Keys are the same camelCase names `applyServerFields` reads, so one
  // vocabulary covers both paths.
  // ---------------------------------------------------------------------
  Map<String, dynamic> toDraftJson() => {
        'registrationType': registrationType.storageValue,
        'supplyingDepots': supplyingDepots,
        'supplyingDepotNames': supplyingDepotNames,
        'accountGroup': grouping,
        'title': title,
        'name1': nameEn,
        'name2': name2,
        'name3': nameKh,
        'coName': coName,
        'searchTerm1': searchTerm,
        'searchTerm2': searchTerm2,
        'depotNumber': depotNumber,
        'street': street,
        'houseNo': houseNumber,
        'city': cityCode,
        'district': districtCode,
        'commune': communeCode,
        'village': villageCode,
        'postalCode': postalCode,
        'region': regionCode,
        'language': language,
        'mobilePhone': mobilePhone,
        'telephone': telephone,
        'telephoneSameAsMobile': telephoneSameAsMobile,
        'faxNumber': faxNumber,
        'contactPersonName': contactPersonName,
        'contactPersonRole': contactPersonRole,
        'salesOrg': salesOrg,
        'salesOffice': salesOffice,
        'salesGroup': salesGroupCode,
        'distributionChannel': distributionChannel,
        'division': divisionCode,
        'depotGroup': depotGroup,
        'priceGroup': priceGroup,
        'priceGroupOverridden': priceGroupOverridden,
        'deliveryPriority': deliveryPriority,
        'shippingCondition': shippingCondition,
        'paymentTerms': paymentTerm,
        'taxClass': taxClass,
        'vatTin': vatTin,
        'currency': currency,
        if (creditLimit != null) 'creditLimit': creditLimit,
        if (serverDepotId != null) 'serverDepotId': serverDepotId,
        if (clientDraftId != null) 'clientDraftId': clientDraftId,
        'isPendingHqApproval': isPendingHqApproval,
        'remark': remark,
        'salesSurvey': salesSurvey.toJson(),
        'latitude': geoFix?.latitude,
        'longitude': geoFix?.longitude,
        'attachments': attachments
            .map((a) => {
                  'kind': a.kind,
                  'local_path': a.localPath,
                  if (a.remoteUrl != null) 'url': a.remoteUrl,
                  'is_uploaded': a.isUploaded,
                  'captured_at': a.capturedAt.toIso8601String(),
                })
            .toList(),
      };

  /// Rebuilds a saved form.
  ///
  /// Reuses [applyServerFields] for the shared keys and then restores the
  /// fields that only exist locally. The gazetteer `GeoAddress` is *not*
  /// restored — only the four codes are, and `GeoLocationSelector` re-resolves
  /// them from `initialCodes` on build. Persisting the resolved object would
  /// pin a rep to a gazetteer revision that a later app version has corrected.
  static BpDepotDraft fromDraftJson(Map<String, dynamic> json) {
    final draft = BpDepotDraft(
      registrationType:
          DepotRegistrationType.fromStorage(json['registrationType']),
      supplyingDepots: [
        for (final code in json['supplyingDepots'] as List? ?? const [])
          if (code is String) code,
      ],
      supplyingDepotNames: {
        for (final MapEntry(:key, :value)
            in (json['supplyingDepotNames'] as Map? ?? const {}).entries)
          if (key is String && value is String) key: value,
      },
      salesSurvey: DepotSalesSurvey.fromJson(json['salesSurvey']),
    )..applyServerFields(json);

    final sameAsMobile = json['telephoneSameAsMobile'];
    if (sameAsMobile is bool) draft.telephoneSameAsMobile = sameAsMobile;

    final overridden = json['priceGroupOverridden'];
    if (overridden is bool) draft.priceGroupOverridden = overridden;

    final serverCustId = json['serverDepotId']?.toString();
    if (serverCustId != null && serverCustId.isNotEmpty) {
      draft.serverDepotId = serverCustId;
    }
    draft.isPendingHqApproval = json['isPendingHqApproval'] == true;
    final clientDraftId = json['clientDraftId']?.toString();
    if (clientDraftId != null && clientDraftId.isNotEmpty) {
      draft.clientDraftId = clientDraftId;
    }

    final attachments = json['attachments'];
    if (attachments is List) {
      for (final raw in attachments.whereType<Map>()) {
        final kind = raw['kind']?.toString();
        final path = raw['local_path']?.toString();
        if (kind == null || path == null || path.isEmpty) continue;
        final capturedAt = raw['captured_at']?.toString();
        draft.attachments.add(BpAttachment(
          kind: kind,
          localPath: path,
          remoteUrl: raw['url']?.toString(),
          isUploaded: raw['is_uploaded'] == true,
          capturedAt: capturedAt == null ? null : DateTime.tryParse(capturedAt),
        ));
      }
    }
    return draft;
  }

  bool get hasKhmerName => RegExp(r'[\u1780-\u17FF]').hasMatch(nameKh);

  bool hasAttachment(String kind) => attachments.any((a) => a.kind == kind);

  BpAttachment? getAttachment(String kind) {
    try {
      return attachments.firstWhere((a) => a.kind == kind);
    } catch (_) {
      return null;
    }
  }

  bool isAttachmentUploaded(String kind) =>
      getAttachment(kind)?.isUploaded == true;

  bool isAttachmentUploading(String kind) =>
      getAttachment(kind)?.isUploading == true;

  bool get allRequiredAttachmentsUploaded {
    final requiredKinds = ['outlet_front', 'outlet_inside', 'id_card'];
    if (taxClass == '1') {
      requiredKinds.add('vat_cert');
    }
    return requiredKinds.every((k) => isAttachmentUploaded(k));
  }

  String get effectiveTelephone =>
      telephoneSameAsMobile ? mobilePhone : telephone;

  /// SAP's street line, carrying the two levels SAP has no field for.
  ///
  /// The BP structure has `city`, `district` and `postalCode` and stops there —
  /// there is no commune/sangkat field and no village field
  /// (`docs/features/create_BP/depot-mobile-registration/api.md`). Sending
  /// them as extra keys would leave them to be dropped by a middleware that
  /// does not model them, so the two levels are folded into the one free-text
  /// field that does reach SAP.
  ///
  /// Ordered street → village → commune because SAP's `STREET` is 60
  /// characters and this truncates from the end: what a delivery driver needs
  /// most is at the front. Province and district are deliberately absent —
  /// they already travel as their own fields, and repeating them would spend
  /// the character budget on data SAP already has.
  String get sapStreetLine {
    final parts = <String>[];
    final base = street.trim();
    if (base.isNotEmpty) parts.add(base);

    final village = geoAddress?.village;
    if (village != null) parts.add('Phum ${village.name.resolve('en')}');

    final commune = geoAddress?.commune;
    if (commune != null) {
      final word = commune.unit == 'Sangkat' ? 'Sangkat' : 'Khum';
      parts.add('$word ${commune.name.resolve('en')}');
    }

    final line = parts.join(', ');
    return line.length <= _sapStreetMaxLength
        ? line
        : line.substring(0, _sapStreetMaxLength).trimRight();
  }

  /// SAP `ADRC-STREET`.
  static const int _sapStreetMaxLength = 60;

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

  // ---------------------------------------------------------------------
  // Per-step validation. Returns field-key -> i18n error key.
  // The UI blocks "Next" while the map is non-empty.
  // ---------------------------------------------------------------------
  /// The server's limit on a non-depot's `depots`.
  static const int maxSupplyingDepots = 20;

  Map<String, String> validateStep(BpFormStep step) {
    final e = <String, String>{};

    switch (step) {
      case BpFormStep.identity:
        if (grouping.isEmpty) e['grouping'] = 'error.required';
        if (title.isEmpty) e['title'] = 'error.required';
        if (nameEn.trim().isEmpty) {
          e['nameEn'] = 'error.required';
        } else if (nameEn.trim().length > 40) {
          e['nameEn'] = 'error.max_40'; // SAP NAME1 is 40 chars
        }
        if (nameKh.trim().isEmpty) {
          e['nameKh'] = 'error.required';
        } else if (!hasKhmerName) {
          e['nameKh'] = 'error.must_be_khmer';
        }
        if (registrationType == DepotRegistrationType.nonBp) {
          if (supplyingDepots.isEmpty) {
            e['supplyingDepots'] = 'error.required';
          } else if (supplyingDepots.length > maxSupplyingDepots) {
            e['supplyingDepots'] = 'error.max_20_depots';
          }
        }
        break;

      case BpFormStep.address:
        if (cityCode == null || cityCode!.isEmpty) e['city'] = 'error.required';
        if (districtCode == null || districtCode!.isEmpty) {
          e['district'] = 'error.required';
        }
        if ((communeCode == null || communeCode!.isEmpty) &&
            geoAddress?.commune == null) {
          e['commune'] = 'error.required';
        }
        // Six digits is the current Cambodia Post scheme and what the
        // gazetteer supplies. Five is still accepted because a rep may be
        // editing a draft saved under the superseded scheme, and rejecting
        // their own stored value would strand them on this step.
        if (!RegExp(r'^\d{5,6}$').hasMatch(postalCode.trim())) {
          e['postalCode'] = 'error.postal_code';
        }
        if (geoFix == null) {
          e['geo'] = 'error.gps_required';
        } else if (!geoFix!.isInsideCambodia) {
          e['geo'] = 'error.gps_outside_kh';
        }
        break;

      case BpFormStep.contact:
        if (mobilePhone.trim().isEmpty) e['mobilePhone'] = 'error.required';
        if (!telephoneSameAsMobile && telephone.trim().isEmpty) {
          e['telephone'] = 'error.required';
        }
        if (contactPersonName.trim().isEmpty) {
          e['contactPersonName'] = 'error.required';
        }
        if (contactPersonRole == null) {
          e['contactPersonRole'] = 'error.required';
        }
        break;

      case BpFormStep.salesTerms:
        // Treated as required even though the server accepts them absent: a
        // record missing the sales area saves happily and can then never be
        // delivered to SAP, which is worse than a validation error the rep can
        // fix while still standing in the shop.
        if (salesOrg == null) e['salesOrg'] = 'error.required';
        if (salesOffice == null) e['salesOffice'] = 'error.required';
        if (salesGroupCode == null) e['salesGroup'] = 'error.required';
        if (distributionChannel == null) {
          e['distributionChannel'] = 'error.required';
        }
        if (divisionCode == null) e['division'] = 'error.required';
        if (depotGroup == null) e['depotGroup'] = 'error.required';
        if (deliveryPriority == null) e['deliveryPriority'] = 'error.required';
        if (shippingCondition == null) {
          e['shippingCondition'] = 'error.required';
        }
        if (paymentTerm == null) e['paymentTerm'] = 'error.required';
        if (taxClass == null) {
          e['taxClass'] = 'error.required';
        } else if (taxClass == '1' && vatTin.trim().isEmpty) {
          e['vatTin'] = 'error.vat_tin_required';
        }
        break;

      case BpFormStep.salesPerformance:
        e.addAll(salesSurvey.validate());
        break;

      case BpFormStep.documents:
        if (!hasAttachment('outlet_front')) {
          e['outlet_front'] = 'error.photo_required';
        }
        if (!hasAttachment('outlet_inside')) {
          e['outlet_inside'] = 'error.photo_required';
        }
        if (!hasAttachment('id_card')) {
          e['id_card'] = 'error.photo_required';
        }
        if (taxClass == '1' && !hasAttachment('vat_cert')) {
          e['vat_cert'] = 'error.photo_required';
        }
        break;

      case BpFormStep.review:
        // No specific validation on the review step itself.
        break;
    }
    return e;
  }

  bool isStepComplete(BpFormStep step) => validateStep(step).isEmpty;

  bool get isReadyToSubmit => BpFormStep.values.every(isStepComplete);

  // The outbound payload used to be built here, by `toSapPayload`. It has been
  // removed rather than deprecated.
  //
  // It emitted the old camelCase keys (`name1`, `salesOrg`, `postalCode`) for
  // the retired three-call draft protocol. The live endpoint takes PascalCase
  // SAP field names (`Name1`, `SalesOrg`, `PostalCode`) and silently drops keys
  // it does not recognise — so leaving the method in place, even marked
  // deprecated, meant one wrong call site produced a registration that the
  // server accepted and SAP received almost entirely blank.
  //
  // The mapping now lives in exactly one place:
  // `data/mappers/bp_draft_to_business_partner.dart`.
}

// =============================================================================
// Read-only block. Populated from SAP after HQ approves; rendered on the
// depot detail screen, NOT inside the creation flow.
// =============================================================================
class BpSapEcho {
  final String? depotCode; // assigned by SAP number range
  final String? reconciliationAccount; // 11001010 - AR End User
  final String? companyCode; // ISI
  final String? paymentTermFi;
  final num? creditLimit; // 50000
  final DateTime? creditChangedOn;
  final bool salesOrderBlock;
  final bool salesSupportBlock;
  final bool deletionFlag;
  final String? createdBy;
  final DateTime? createdOn;
  final String? lastChangedBy;
  final DateTime? lastChangedOn;
  final String? bankKey;
  final String? bankAccount;
  final String? accountHolder;
  final String? financeInstitution;

  const BpSapEcho({
    this.depotCode,
    this.reconciliationAccount,
    this.companyCode,
    this.paymentTermFi,
    this.creditLimit,
    this.creditChangedOn,
    this.salesOrderBlock = false,
    this.salesSupportBlock = false,
    this.deletionFlag = false,
    this.createdBy,
    this.createdOn,
    this.lastChangedBy,
    this.lastChangedOn,
    this.bankKey,
    this.bankAccount,
    this.accountHolder,
    this.financeInstitution,
  });
}
