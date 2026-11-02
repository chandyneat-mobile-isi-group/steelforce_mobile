import 'package:equatable/equatable.dart';

/// One SAP sales area of a new depot. Every value is a reference **code**,
/// kept as a string so `"0001"` never becomes `1`.
///
/// The six required codes each come from their own list in
/// `GET /api/v1/depots/references`. [division] is optional and not checked by
/// the server (divisions are not synced). [salesEmployee] is left null by a
/// sales rep — the server fills in the caller's own code.
class DepotDraftSalesArea extends Equatable {
  const DepotDraftSalesArea({
    required this.key,
    this.id,
    this.salesOrg,
    this.distributionChannel,
    this.division,
    this.customerGroup,
    this.salesOffice,
    this.shippingCondition,
    this.paymentTerms,
    this.salesEmployee,
  });

  /// Local, stable row identity for list keys and edits. Never sent.
  final String key;

  /// The server's id on a saved draft; null for a new row.
  final String? id;

  final String? salesOrg;
  final String? distributionChannel;
  final String? division;
  final String? customerGroup;
  final String? salesOffice;
  final String? shippingCondition;
  final String? paymentTerms;
  final String? salesEmployee;

  /// The required codes are all chosen.
  bool get isComplete => [
        salesOrg,
        distributionChannel,
        customerGroup,
        salesOffice,
        shippingCondition,
        paymentTerms,
      ].every((code) => code != null && code.trim().isNotEmpty);

  /// What the server keeps unique within one draft.
  (String?, String?, String?) get identity =>
      (salesOrg, distributionChannel, division);

  @override
  List<Object?> get props => [
        key,
        id,
        salesOrg,
        distributionChannel,
        division,
        customerGroup,
        salesOffice,
        shippingCondition,
        paymentTerms,
        salesEmployee,
      ];
}
