// =============================================================================
// bp_depot_draft.dart
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

import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/geo_fix.dart';
import 'package:steelforce/features/depots/domain/entities/sap_bp_const.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';

// Re-exported so every caller of the draft keeps its rules without a second
// import. Saving and loading the draft is not here: that is persistence, in
// `data/mappers/bp_draft_json_mapper.dart`.
export 'package:steelforce/features/depots/domain/entities/bp_depot_draft_derivations.dart';
export 'package:steelforce/features/depots/domain/entities/bp_depot_draft_validation.dart';

// =============================================================================
// The draft the rep builds up across the five steps.
// =============================================================================
class BpDepotDraft {
  // --- Step 1: Identity -------------------------------------------------
  String grouping; // REP   Grouping            (Z001)
  String title; // REP   Title               (0003)
  String nameEn; // REP   Name 1 (EN)        *
  String nameKh; // REP   Name 3 (KH)        *
  String name2; // REP   Name 2              (optional)
  /// `SearchTerm1` on the wire. Holds the *place* — the sample payload sends
  /// `PHNOM PENH` here and the shop shorthand in `SearchTerm2`.
  ///
  /// Left as `searchTerm` rather than renamed to `searchTerm1`, because the
  /// name is persisted in locally saved drafts and in `applyBpServerFields`; a
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

  // --- Step 5: Documents ------------------------------------------------
  final List<BpAttachment> attachments;
  String remark;

  BpDepotDraft({
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
    List<BpAttachment>? attachments,
    this.remark = '',
  }) : attachments = attachments ?? <BpAttachment>[];

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
