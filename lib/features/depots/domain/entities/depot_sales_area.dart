import 'package:equatable/equatable.dart';

/// One SAP sales area of an outlet (sales org × channel × division), with the
/// terms SAP keeps for it. Read-only: SAP owns every field.
class DepotSalesArea extends Equatable {
  const DepotSalesArea({
    this.salesOrgCode,
    this.salesOrgName,
    this.channelCode,
    this.channelName,
    this.division,
    this.divisionName,
    this.paymentTermsCode,
    this.paymentTermsName,
    this.creditLimit,
    this.creditLimitDate,
    this.creditTermDays,
  });

  final String? salesOrgCode;
  final String? salesOrgName;
  final String? channelCode;
  final String? channelName;
  final String? division;

  /// [division]'s name. The server sends only the code; the repository names
  /// it from SAP's division list.
  final String? divisionName;
  final String? paymentTermsCode;
  final String? paymentTermsName;

  /// In the depot's currency. Null when SAP sent none.
  final double? creditLimit;

  /// When SAP last set [creditLimit]; null when SAP never dated it
  /// (it sends `00000000`).
  final DateTime? creditLimitDate;

  /// Days of credit. Null when not set — cash on delivery has none.
  final int? creditTermDays;

  @override
  List<Object?> get props => [
        salesOrgCode,
        salesOrgName,
        channelCode,
        channelName,
        division,
        divisionName,
        paymentTermsCode,
        paymentTermsName,
        creditLimit,
        creditLimitDate,
        creditTermDays,
      ];

  DepotSalesArea withDivisionName(String? name) => DepotSalesArea(
        salesOrgCode: salesOrgCode,
        salesOrgName: salesOrgName,
        channelCode: channelCode,
        channelName: channelName,
        division: division,
        divisionName: name,
        paymentTermsCode: paymentTermsCode,
        paymentTermsName: paymentTermsName,
        creditLimit: creditLimit,
        creditLimitDate: creditLimitDate,
        creditTermDays: creditTermDays,
      );
}
