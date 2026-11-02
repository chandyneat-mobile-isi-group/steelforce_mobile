import 'package:equatable/equatable.dart';

/// One pick-list value: show [name], submit [code] verbatim.
class ReferenceOption extends Equatable {
  const ReferenceOption({required this.code, required this.name});

  /// Kept as text — `"0001"` and `"01"` are keys, not numbers.
  final String code;

  /// Null when the server has no name for the code; the UI shows the code.
  final String? name;

  @override
  List<Object?> get props => [code, name];
}

/// The six SAP lists of `GET /api/v1/depots/references`, each ordered by code.
///
/// An empty list means "never synced" (the server returns `[]`, never omits
/// one), so the form can say the data is not ready instead of offering
/// nothing. Divisions, sales groups and price groups are not in this response.
class DepotReferenceLists extends Equatable {
  const DepotReferenceLists({
    this.salesOrgs = const [],
    this.distributionChannels = const [],
    this.customerGroups = const [],
    this.salesOffices = const [],
    this.shippingConditions = const [],
    this.paymentTerms = const [],
  });

  final List<ReferenceOption> salesOrgs;
  final List<ReferenceOption> distributionChannels;
  final List<ReferenceOption> customerGroups;
  final List<ReferenceOption> salesOffices;
  final List<ReferenceOption> shippingConditions;
  final List<ReferenceOption> paymentTerms;

  /// Every required sales-area list has at least one value.
  bool get canCompleteSalesArea => [
        salesOrgs,
        distributionChannels,
        customerGroups,
        salesOffices,
        shippingConditions,
        paymentTerms,
      ].every((list) => list.isNotEmpty);

  @override
  List<Object?> get props => [
        salesOrgs,
        distributionChannels,
        customerGroups,
        salesOffices,
        shippingConditions,
        paymentTerms,
      ];
}

/// A Branch or Factory a depot can buy from, bilingual as the server keeps it.
class SupplierOption extends Equatable {
  const SupplierOption({
    required this.code,
    required this.nameEn,
    this.nameKh,
    this.isActive = true,
  });

  final String code;
  final String nameEn;
  final String? nameKh;
  final bool isActive;

  @override
  List<Object?> get props => [code, nameEn, nameKh, isActive];
}
