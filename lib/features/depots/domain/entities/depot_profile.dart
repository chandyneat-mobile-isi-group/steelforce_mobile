import 'package:equatable/equatable.dart';

/// Someone assigned to the outlet, with their org unit as of today. An org
/// unit is null when the employee has no SteelForce account or no assignment
/// today; the name then comes from SAP.
class DepotSalesEmployee extends Equatable {
  const DepotSalesEmployee({
    this.employeeCode,
    this.employeeName,
    this.territoryCode,
    this.territoryName,
    this.branchCode,
    this.branchName,
    this.regionCode,
    this.regionName,
  });

  final String? employeeCode;
  final String? employeeName;
  final String? territoryCode;
  final String? territoryName;
  final String? branchCode;
  final String? branchName;
  final String? regionCode;
  final String? regionName;

  @override
  List<Object?> get props => [
        employeeCode,
        employeeName,
        territoryCode,
        territoryName,
        branchCode,
        branchName,
        regionCode,
        regionName,
      ];
}

/// The outlet's `profile`: what the field team recorded, who supplies it, and
/// how it is managed. Every value is optional — the server sends null for
/// anything not captured yet, and the details screen shows that as such.
///
/// Values are kept as display text: the server's shapes for these are not
/// fixed yet, so an object (a supplier's `{type, code}`) arrives flattened.
class DepotProfile extends Equatable {
  const DepotProfile({
    this.telegram,
    this.outletStatus,
    this.houseNumber,
    this.addressLine,
    this.primarySupplier,
    this.secondarySupplier,
    this.tertiarySupplier,
    this.primarySupplierCode,
    this.secondarySupplierCode,
    this.tertiarySupplierCode,
    this.tier,
    this.channel,
    this.subChannel,
    this.outletAction,
    this.keyAccountId,
    this.coverageType,
    this.visit,
    this.territory,
  });

  // `fieldFacts`
  final String? telegram;
  final String? outletStatus;
  final String? houseNumber;
  final String? addressLine;

  // `suppliers`
  final String? primarySupplier;
  final String? secondarySupplier;
  final String? tertiarySupplier;

  /// Each supplier's code, which opens it — null when only a name is known.
  final String? primarySupplierCode;
  final String? secondarySupplierCode;
  final String? tertiarySupplierCode;

  // `management`
  final String? tier;
  final String? channel;
  final String? subChannel;
  final String? outletAction;
  final String? keyAccountId;
  final String? coverageType;
  final String? visit;
  final String? territory;

  @override
  List<Object?> get props => [
        telegram,
        outletStatus,
        houseNumber,
        addressLine,
        primarySupplier,
        secondarySupplier,
        tertiarySupplier,
        primarySupplierCode,
        secondarySupplierCode,
        tertiarySupplierCode,
        tier,
        channel,
        subChannel,
        outletAction,
        keyAccountId,
        coverageType,
        visit,
        territory,
      ];
}
