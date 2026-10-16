/// The commercial detail a demo depot carries beyond its shared identity.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

class DemoDepotProfile {
  const DemoDepotProfile({
    required this.street,
    required this.territory,
    required this.status,
    required this.outletType,
    required this.depotGroup,
    required this.priceGroup,
    required this.paymentTerm,
    required this.creditLimit,
    required this.creditBalance,
    required this.lifetimeValue,
    required this.totalOrders,
    required this.lastVisitDaysAgo,
    required this.lastOrderDaysAgo,
    required this.contacts,
    this.openOpportunities = 0,
    this.telegram,
    this.taxNumber,
  });

  final String street;
  final String territory;

  final String status; // the API's stable code, e.g. `Suspended`

  /// `Retailer` · `Wholesaler` · `Distributor` · `KeyAccount`.
  final String outletType;

  /// Codes from `DemoRegistrationReferences`.
  final String depotGroup;
  final String priceGroup;
  final String paymentTerm;

  final double creditLimit;
  final double creditBalance;
  final double lifetimeValue;
  final int totalOrders;
  final int lastVisitDaysAgo;
  final int? lastOrderDaysAgo; // null: never ordered
  final List<DemoDepotContact> contacts;
  final int openOpportunities;
  final String? telegram;
  final String? taxNumber;

  bool get isInSap => status != 'PendingApproval' && status != 'Draft';
}

class DemoDepotContact {
  const DemoDepotContact(this.name, this.position, this.phone);

  final String name;
  final String position;
  final String phone;
}
