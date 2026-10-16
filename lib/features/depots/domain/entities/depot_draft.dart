import 'package:equatable/equatable.dart';

/// A new depot as the rep entered it, before the server has accepted it.
///
/// Deliberately separate from [Depot]: a `Depot` has an id, a status and
/// a SAP identity, none of which exist yet. This is only the writable subset —
/// **the SAP block (`sapDepotId`, `salesOrg`, `division`,
/// `distributionChannel`, `depotGroup`, `priceGroup`, `paymentTerms`) is
/// returned by the API but never accepted on write.** SAP owns that data, and
/// letting a phone set `salesOrg` would let the field invent master data the
/// ERP then contradicts.
///
/// A created depot starts in `Draft` and cannot trade until someone holding
/// `depots.approve` activates it. Ownership defaults to the caller, so a
/// rep registering a shop owns that relationship without a separate assignment.
class DepotDraft extends Equatable {
  const DepotDraft({
    required this.depotCode,
    required this.shopName,
    required this.type,
    required this.phone,
    required this.addressLine1,
    required this.city,
    this.district,
    this.province,
    this.ownerName,
    this.whatsapp,
    this.territory,
    this.latitude,
    this.longitude,
    this.creditLimit,
    this.creditTermDays,
    this.enName,
    this.khName,
    this.contacts = const [],
  });

  /// Immutable once created — renaming it would orphan every SAP document,
  /// order and statement that references it. Duplicates are rejected with
  /// `Depot.DuplicateCode` (409).
  final String depotCode;

  final String shopName;

  /// `Retailer`, `Wholesaler`, `Distributor` or `KeyAccount`. An unrecognised
  /// value comes back as `General.Validation`, not `Depot.TypeInvalid`,
  /// because request validation runs before the domain sees the payload.
  final String type;

  /// Human formatting is fine — `012 345 678`, `+855-12-345-678` and
  /// `012345678` are all accepted. Spaces, dashes and brackets are stripped
  /// server-side, so never make a rep retype a number because of a space.
  final String phone;

  final String addressLine1;
  final String city;
  final String? district;
  final String? province;
  final String? ownerName;
  final String? whatsapp;
  final String? territory;

  /// **Send both or neither, and never `(0, 0)`.**
  ///
  /// One without the other is a 400. `(0, 0)` is a real point in the Gulf of
  /// Guinea and exactly what a device reports when the GPS fix failed, so the
  /// server rejects it with `Depot.CoordinatesMissing` — send null for both
  /// when there is no fix.
  final double? latitude;
  final double? longitude;

  /// Must be >= 0. Outside 0–180 days, [creditTermDays] is rejected.
  final double? creditLimit;
  final int? creditTermDays;

  /// Returned regardless of requested language — a delivery note carries the
  /// Khmer shopfront name and the English legal name together.
  final String? enName;
  final String? khName;

  final List<DepotContactDraft> contacts;

  /// True when a usable fix was captured. Guards the send: partial coordinates
  /// are a 400 and zeros are a rejection.
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  /// The create payload.
  ///
  /// Optional keys are omitted rather than sent null where the distinction
  /// matters, and coordinates are sent as a pair or not at all.
  Map<String, dynamic> toJson() => {
        'depotCode': depotCode,
        'shopName': shopName,
        'type': type,
        'phone': phone,
        'addressLine1': addressLine1,
        'city': city,
        if (district != null) 'district': district,
        if (province != null) 'province': province,
        if (ownerName != null) 'ownerName': ownerName,
        if (whatsapp != null) 'whatsapp': whatsapp,
        if (territory != null) 'territory': territory,
        // Both or neither: latitude without longitude is a 400, and zeros are
        // read as a failed GPS fix rather than as a location.
        if (hasCoordinates) ...{
          'latitude': latitude,
          'longitude': longitude,
        },
        if (creditLimit != null) 'creditLimit': creditLimit,
        if (creditTermDays != null) 'creditTermDays': creditTermDays,
        if (enName != null) 'enName': enName,
        if (khName != null) 'khName': khName,
        // Omitted entirely when empty. On update an empty array **removes every
        // contact**, so "no contacts supplied" must never serialise as `[]`.
        if (contacts.isNotEmpty)
          'contacts': contacts.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props => [depotCode, shopName, type, phone, city];
}

/// A contact on a new depot. At most one may be primary; marking a second
/// promotes it and demotes the previous one rather than failing, so there is
/// never a window with no primary.
class DepotContactDraft extends Equatable {
  const DepotContactDraft({
    required this.name,
    required this.phone,
    this.position,
    this.isPrimary = false,
  });

  final String name;
  final String phone;
  final String? position;
  final bool isPrimary;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        if (position != null) 'position': position,
        'isPrimary': isPrimary,
      };

  @override
  List<Object?> get props => [name, phone, position, isPrimary];
}
