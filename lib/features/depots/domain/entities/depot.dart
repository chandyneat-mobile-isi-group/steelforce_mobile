import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/depots/domain/entities/depot_contact.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// An approved business depot that already exists in SAP.
///
/// This is deliberately **not** a superset of `Lead` — it only ever comes
/// into being via sync from the SAP depot master
/// ([DepotRemoteDataSource]/`upsertFromSapPayload`). There is no local
/// constructor path for a rep to hand-create one; that would violate the
/// Won -> Submitted -> HQ Approved -> SAP-created entry rule.
/// [sapDepotId] is **nullable**: a depot registered in the field has no
/// SAP identity until it is approved and pushed to the ERP. It was non-null
/// while depots could only arrive by sync from SAP; now that a rep can
/// create one, `Draft` and `PendingApproval` records legitimately have none.
class Depot extends Equatable {
  const Depot({
    required this.id,
    this.sapDepotId,
    required this.depotCode,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.province,
    required this.district,
    required this.territory,
    required this.latitude,
    required this.longitude,
    required this.creditLimit,
    required this.status,
    required this.assignedRepId,
    required this.assignedRepName,
    required this.updatedAt,
    this.email,
    this.whatsapp,
    this.originLeadId,
    this.productsPurchased = const [],
    this.contacts = const [],
    this.lastOrderDate,
    this.lastVisitDate,
    this.lifetimeValue = 0,
    this.openOpportunityCount = 0,
    this.salesOrg,
    this.division,
    this.distributionChannel,
    this.depotGroup,
    this.priceGroup,
    this.enName,
    this.khName,
    this.taxNumber,
    this.creditBalance = 0,
    this.currency = 'USD',
    this.totalOrders = 0,
    this.createdAt,
  });

  final String id;

  /// The ERP's identifier, once it has one. Null until SAP creates the record.
  final String? sapDepotId;
  final String depotCode;
  final String shopName;
  final String ownerName;
  final String phone;
  final String? email;
  final String? whatsapp;
  final String address;
  final String province;
  final String district;
  final String territory;
  final double latitude;
  final double longitude;

  /// SAP/HQ-controlled financials — read-only on the mobile app.
  final double creditLimit;
  final DepotStatus status;

  final String assignedRepId;
  final String assignedRepName;
  final DateTime updatedAt;

  /// The Lead this depot originated from, kept for traceability only —
  /// there is no foreign key back to `leads` and nothing here ever writes
  /// to that Lead again.
  final String? originLeadId;

  final List<String> productsPurchased;
  final List<DepotContact> contacts;
  final DateTime? lastOrderDate;
  final DateTime? lastVisitDate;
  final double lifetimeValue;
  final int openOpportunityCount;

  // ── SAP sales area (schema v9) ──────────────────────────────────────
  // Nullable because SAP leaves the sales area blank until a depot is
  // assigned one, and because rows written before v9 have no value. A filter
  // must treat null as "unassigned", never as a match.
  final String? salesOrg;
  final String? division;
  final String? distributionChannel;

  /// SAP commercial classification.
  final String? depotGroup;
  final String? priceGroup;

  /// SAP `name1` / `name3`. [shopName] remains the display name; these are the
  /// legal names used for search and printed documents.
  final String? enName;
  final String? khName;

  /// VAT / tax identification number.
  final String? taxNumber;

  /// Consumed portion of [creditLimit]; [availableCredit] is the useful figure.
  final double creditBalance;
  final String currency;

  /// Lifetime order count — the countable twin of [lifetimeValue].
  final int totalOrders;

  /// When SAP created the record ([updatedAt] covers modification).
  final DateTime? createdAt;

  /// Whether this depot has a usable position.
  ///
  /// `(0, 0)` encodes "no GPS fix was ever captured". It is a real point in the
  /// Gulf of Guinea, which is precisely why the API rejects it on write and
  /// sends null instead — but the local schema declares both columns non-null,
  /// so that pair is what a coordinate-less depot stores.
  ///
  /// **Every geographic consumer must check this first.** A distance sorter or
  /// geofence that skips the check will happily measure the 10 000 km to the
  /// Atlantic and rank an unlocated shop as impossibly far, or fail a check-in
  /// the rep is standing inside.
  bool get hasCoordinates => latitude != 0 || longitude != 0;

  /// The depot's name in both languages, for rendering.
  ///
  /// English resolves to [shopName] rather than [enName] deliberately:
  /// [shopName] is non-nullable and populated for every row, while SAP leaves
  /// `name1` blank on plenty of accounts. Falling back the other way would
  /// blank out the directory for exactly the depots with the least master
  /// data — the ones a rep most needs to find.
  ///
  /// Khmer resolves to [khName] (SAP `name3`). Where SAP carries no Khmer name,
  /// [LocalizedText.resolve] falls back to English, so a Khmer session shows a
  /// Latin shop name instead of an empty row.
  ///
  /// Widgets render `context.localized(depot.displayName)`. Nothing is
  /// re-fetched on a language switch because both languages are already here —
  /// the same design as [Product.displayName] and [Category.name].
  LocalizedText get displayName =>
      LocalizedText(en: shopName, km: khName ?? '');

  /// Everything the directory search should match, in every language at once.
  ///
  /// Spans both languages regardless of the active locale on purpose: a rep who
  /// knows a shop by its Khmer name types that whether or not the UI is in
  /// Khmer, and returning nothing would be a defect. The DAO applies the same
  /// rule in SQL (`DepotDao.browse`); this is the in-memory twin, used where
  /// a list is already loaded and re-querying would be wasteful.
  Iterable<String> get searchableValues sync* {
    yield* displayName.allValues;
    if ((enName?.trim().isNotEmpty ?? false) && enName != shopName) {
      yield enName!;
    }
    yield depotCode;
    // Searchable only once it exists — an unsynced depot has no SAP number
    // to match against, and yielding null would poison the token set.
    if (sapDepotId case final sapId?) yield sapId;
    yield ownerName;
    yield phone;
  }

  /// Headroom left against the credit limit. Clamped at zero so an
  /// over-limit account reads as "no credit available" rather than negative.
  double get availableCredit {
    final remaining = creditLimit - creditBalance;
    return remaining < 0 ? 0 : remaining;
  }

  /// True once SAP has assigned a full sales area. Screens that act on sales
  /// area should check this rather than null-testing three fields.
  bool get hasSalesArea =>
      (salesOrg?.isNotEmpty ?? false) && (division?.isNotEmpty ?? false);

  Depot copyWith({
    String? id,
    String? sapDepotId,
    String? depotCode,
    String? shopName,
    String? ownerName,
    String? phone,
    String? address,
    String? province,
    String? district,
    String? territory,
    double? latitude,
    double? longitude,
    double? creditLimit,
    DepotStatus? status,
    String? assignedRepId,
    String? assignedRepName,
    DateTime? updatedAt,
    String? email,
    String? whatsapp,
    String? originLeadId,
    List<String>? productsPurchased,
    List<DepotContact>? contacts,
    DateTime? lastOrderDate,
    DateTime? lastVisitDate,
    double? lifetimeValue,
    int? openOpportunityCount,
    String? salesOrg,
    String? division,
    String? distributionChannel,
    String? depotGroup,
    String? priceGroup,
    String? enName,
    String? khName,
    String? taxNumber,
    double? creditBalance,
    String? currency,
    int? totalOrders,
    DateTime? createdAt,
  }) {
    return Depot(
      id: id ?? this.id,
      sapDepotId: sapDepotId ?? this.sapDepotId,
      depotCode: depotCode ?? this.depotCode,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      province: province ?? this.province,
      district: district ?? this.district,
      territory: territory ?? this.territory,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      creditLimit: creditLimit ?? this.creditLimit,
      status: status ?? this.status,
      assignedRepId: assignedRepId ?? this.assignedRepId,
      assignedRepName: assignedRepName ?? this.assignedRepName,
      updatedAt: updatedAt ?? this.updatedAt,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
      originLeadId: originLeadId ?? this.originLeadId,
      productsPurchased: productsPurchased ?? this.productsPurchased,
      contacts: contacts ?? this.contacts,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      lifetimeValue: lifetimeValue ?? this.lifetimeValue,
      openOpportunityCount: openOpportunityCount ?? this.openOpportunityCount,
      salesOrg: salesOrg ?? this.salesOrg,
      division: division ?? this.division,
      distributionChannel: distributionChannel ?? this.distributionChannel,
      depotGroup: depotGroup ?? this.depotGroup,
      priceGroup: priceGroup ?? this.priceGroup,
      enName: enName ?? this.enName,
      khName: khName ?? this.khName,
      taxNumber: taxNumber ?? this.taxNumber,
      creditBalance: creditBalance ?? this.creditBalance,
      currency: currency ?? this.currency,
      totalOrders: totalOrders ?? this.totalOrders,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sapDepotId,
        depotCode,
        shopName,
        ownerName,
        phone,
        email,
        whatsapp,
        address,
        province,
        district,
        territory,
        latitude,
        longitude,
        creditLimit,
        status,
        assignedRepId,
        assignedRepName,
        updatedAt,
        originLeadId,
        productsPurchased,
        contacts,
        lastOrderDate,
        lastVisitDate,
        lifetimeValue,
        openOpportunityCount,
        salesOrg,
        division,
        distributionChannel,
        depotGroup,
        priceGroup,
        enName,
        khName,
        taxNumber,
        creditBalance,
        currency,
        totalOrders,
        createdAt,
      ];
}
