part of 'add_depot_bloc.dart';

sealed class AddDepotEvent {}

class UpdateShopDetails extends AddDepotEvent {
  UpdateShopDetails({
    required this.depotCode,
    required this.shopName,
    required this.shopType,
    required this.ownerName,
    required this.addressLine1,
    required this.city,
  });

  /// Immutable once created — renaming it would orphan every SAP document
  /// that references it. A clash returns `Depot.DuplicateCode` (409).
  final String depotCode;

  final String shopName;

  /// One of the API's trade types: `Retailer`, `Wholesaler`, `Distributor`,
  /// `KeyAccount`.
  final String shopType;

  final String ownerName;

  /// Required by the API — blank is `Depot.AddressLineRequired`.
  final String addressLine1;

  /// Required by the API — blank is `Depot.AddressCityRequired`.
  final String city;
}

class UpdateContactDetails extends AddDepotEvent {
  UpdateContactDetails({
    required this.name,
    required this.role,
    required this.phone,
  });

  final String name;
  final String role;

  /// Human formatting is fine; the server strips spaces, dashes and brackets.
  final String phone;
}

class UpdateLocationAndPapers extends AddDepotEvent {
  UpdateLocationAndPapers({
    required this.gpsLocation,
    required this.businessLicencePath,
    required this.taxPaperPath,
    this.latitude,
    this.longitude,
  });

  /// Display string only. The values actually sent are [latitude] and
  /// [longitude].
  final String gpsLocation;

  /// **Null when the fix failed.** Never zero — `(0, 0)` is a real point in
  /// the Gulf of Guinea and what a device reports when GPS gave up, so the
  /// server rejects it with `Depot.CoordinatesMissing`.
  final double? latitude;
  final double? longitude;

  final String businessLicencePath;
  final String taxPaperPath;
}

class NextStep extends AddDepotEvent {}

class PreviousStep extends AddDepotEvent {}

class SubmitToHQ extends AddDepotEvent {}
