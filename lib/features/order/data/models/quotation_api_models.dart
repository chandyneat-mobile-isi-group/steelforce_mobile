import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

class QuotationSummaryModel extends QuotationSummary {
  const QuotationSummaryModel({
    required super.id,
    required super.number,
    required super.depotId,
    required super.depotName,
    required super.status,
    required super.statusGroup,
    required super.net,
    required super.lineCount,
    required super.createdAt,
    super.currency,
    super.validTo,
    super.updatedAt,
  });

  factory QuotationSummaryModel.fromJson(DataMap json) {
    return QuotationSummaryModel(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      depotId: json['customerId'] as String? ?? '',
      depotName: json['customerName'] as String? ?? '',
      status: json['status'] as String? ?? 'Draft',
      statusGroup:
          QuotationStatusGroup.fromWire(json['statusGroup'] as String?),
      currency: json['currency'] as String?,
      net: (json['net'] as num?)?.toDouble() ?? 0.0,
      lineCount: json['lineCount'] as int? ?? 0,
      validTo: json['validTo'] != null
          ? DateTime.tryParse(json['validTo'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

class QuotationLineDiscountModel extends QuotationLineDiscount {
  const QuotationLineDiscountModel({
    required super.id,
    required super.kind,
    required super.percent,
    required super.editable,
    super.sourceReference,
    super.sapConditionType,
    super.estimateAmount,
    super.sapAmount,
  });

  factory QuotationLineDiscountModel.fromJson(DataMap json) {
    return QuotationLineDiscountModel(
      id: json['id'] as String? ?? '',
      kind: QuotationDiscountKind.fromValue(json['kind']),
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      editable: json['editable'] as bool? ?? false,
      sourceReference: json['sourceReference'] as String?,
      sapConditionType: json['sapConditionType'] as String?,
      estimateAmount: (json['estimateAmount'] as num?)?.toDouble(),
      sapAmount: (json['sapAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.value,
        'percent': percent,
        'editable': editable,
        if (sourceReference != null) 'sourceReference': sourceReference,
        if (sapConditionType != null) 'sapConditionType': sapConditionType,
        if (estimateAmount != null) 'estimateAmount': estimateAmount,
        if (sapAmount != null) 'sapAmount': sapAmount,
      };
}

class QuotationLineModel extends QuotationLineItem {
  const QuotationLineModel({
    required super.id,
    required super.lineNumber,
    required super.materialNumber,
    required super.materialDescription,
    required super.quantity,
    required super.unit,
    required super.priceAmount,
    required super.priceCurrency,
    required super.pricePricingUnit,
    required super.priceConditionUnit,
    required super.discounts,
    required super.gross,
    required super.discountTotal,
    required super.net,
    super.category,
  });

  factory QuotationLineModel.fromJson(DataMap json) {
    final discountsList = (json['discounts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) =>
            QuotationLineDiscountModel.fromJson(m.cast<String, dynamic>()))
        .toList();

    return QuotationLineModel(
      id: json['id'] as String? ?? '',
      lineNumber: json['lineNumber'] as int? ?? 1,
      materialNumber: json['materialNumber'] as String? ?? '',
      materialDescription: json['materialDescription'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'KG',
      priceAmount: (json['priceAmount'] as num?)?.toDouble() ??
          (json['price']?['amount'] as num?)?.toDouble() ??
          0.0,
      priceCurrency: json['priceCurrency'] as String? ??
          json['price']?['currency'] as String? ??
          'US3',
      pricePricingUnit: (json['pricePricingUnit'] as num?)?.toDouble() ??
          (json['price']?['pricingUnit'] as num?)?.toDouble() ??
          1.0,
      priceConditionUnit: json['priceConditionUnit'] as String? ??
          json['price']?['conditionUnit'] as String? ??
          'KG',
      discounts: discountsList,
      gross: (json['gross'] as num?)?.toDouble() ??
          (json['estimateGross'] as num?)?.toDouble() ??
          0.0,
      discountTotal: (json['discountTotal'] as num?)?.toDouble() ??
          (json['estimateDiscountTotal'] as num?)?.toDouble() ??
          0.0,
      net: (json['net'] as num?)?.toDouble() ??
          (json['estimateNet'] as num?)?.toDouble() ??
          0.0,
      category: json['category'] as String?,
    );
  }
}

class QuotationTotalsModel extends QuotationTotals {
  const QuotationTotalsModel({
    required super.currency,
    required super.gross,
    required super.discountTotal,
    required super.net,
    required super.isEstimate,
    super.tax,
  });

  factory QuotationTotalsModel.fromJson(DataMap json) {
    return QuotationTotalsModel(
      currency: json['currency'] as String? ?? 'US3',
      gross: (json['gross'] as num?)?.toDouble() ?? 0.0,
      discountTotal: (json['discountTotal'] as num?)?.toDouble() ?? 0.0,
      net: (json['net'] as num?)?.toDouble() ?? 0.0,
      isEstimate: json['isEstimate'] as bool? ?? true,
      tax: (json['tax'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'gross': gross,
        'discountTotal': discountTotal,
        'net': net,
        'isEstimate': isEstimate,
        'tax': tax,
      };
}

class QuotationDetailModel extends QuotationDetail {
  const QuotationDetailModel({
    required super.id,
    required super.number,
    required super.depotId,
    required super.depotName,
    required super.status,
    required super.statusGroup,
    required super.shipmentType,
    required super.lines,
    required super.totals,
    required super.revision,
    required super.requiredApprovalLevel,
    super.currency,
    super.shipTo,
    super.paymentTerm,
    super.depotReference,
    super.remarks,
    super.decisionReason,
    super.validFrom,
    super.validTo,
    super.submittedAt,
    super.decidedAt,
    super.decidedBy,
    super.createdAt,
    super.updatedAt,
  });

  factory QuotationDetailModel.fromJson(DataMap json) {
    final linesList = (json['lines'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) => QuotationLineModel.fromJson(m.cast<String, dynamic>()))
        .toList();

    final totalsMap = (json['totals'] as Map?)?.cast<String, dynamic>() ?? {};

    return QuotationDetailModel(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      depotId: json['customerId'] as String? ?? '',
      depotName: json['customerName'] as String?,
      status: json['status'] as String? ?? 'Draft',
      statusGroup:
          QuotationStatusGroup.fromWire(json['statusGroup'] as String?),
      currency: json['currency'] as String?,
      shipmentType: json['shipmentType'] as String? ?? 'Pickup',
      shipTo: json['shipTo'] as String?,
      paymentTerm: json['paymentTerm'] as String?,
      depotReference: json['customerReference'] as String?,
      remarks: json['remarks'] as String?,
      lines: linesList,
      totals: QuotationTotalsModel.fromJson(totalsMap),
      revision: json['revision'] as int? ?? 1,
      requiredApprovalLevel: json['requiredApprovalLevel'] as int? ?? 1,
      decisionReason: json['decisionReason'] as String?,
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'] as String)
          : null,
      validTo: json['validTo'] != null
          ? DateTime.tryParse(json['validTo'] as String)
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      decidedAt: json['decidedAt'] != null
          ? DateTime.tryParse(json['decidedAt'] as String)
          : null,
      decidedBy: json['decidedBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

class QuotationWarningModel extends QuotationWarning {
  const QuotationWarningModel({
    required super.code,
    super.lineId,
    super.message,
  });

  factory QuotationWarningModel.fromJson(DataMap json) {
    return QuotationWarningModel(
      code: json['code'] as String? ?? '',
      lineId: json['lineId'] as String?,
      message: json['message'] as String?,
    );
  }
}

class QuotationPreviewModel extends QuotationPreviewData {
  const QuotationPreviewModel({
    required super.quotationId,
    required super.lines,
    required super.totals,
    required super.warnings,
    required super.manualDiscountLimitPercent,
    required super.lineDiscountCapPercent,
    required super.requiredApprovalLevel,
  });

  factory QuotationPreviewModel.fromJson(DataMap json) {
    final linesList = (json['lines'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) => QuotationLineModel.fromJson(m.cast<String, dynamic>()))
        .toList();

    final warningsList = (json['warnings'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) => QuotationWarningModel.fromJson(m.cast<String, dynamic>()))
        .toList();

    final totalsMap = (json['totals'] as Map?)?.cast<String, dynamic>() ?? {};

    return QuotationPreviewModel(
      quotationId:
          json['quotationId'] as String? ?? json['id'] as String? ?? '',
      lines: linesList,
      totals: QuotationTotalsModel.fromJson(totalsMap),
      warnings: warningsList,
      manualDiscountLimitPercent:
          (json['manualDiscountLimitPercent'] as num?)?.toDouble() ?? 10.0,
      lineDiscountCapPercent:
          (json['lineDiscountCapPercent'] as num?)?.toDouble() ?? 15.0,
      requiredApprovalLevel: json['requiredApprovalLevel'] as int? ?? 1,
    );
  }
}

class QuotationHistoryRecordModel extends QuotationApprovalHistory {
  const QuotationHistoryRecordModel({
    required super.id,
    required super.action,
    required super.createdAt,
    super.actorId,
    super.actorName,
    super.comment,
  });

  factory QuotationHistoryRecordModel.fromJson(DataMap json) {
    return QuotationHistoryRecordModel(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? 'Created',
      createdAt: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now(),
      actorId: json['actorId'] as String?,
      actorName: json['actorName'] as String?,
      comment: json['comment'] as String? ?? json['reason'] as String?,
    );
  }
}

class DepotAgreementModel extends DepotAgreement {
  const DepotAgreementModel({
    required super.id,
    required super.category,
    required super.percent,
    required super.kind,
    required super.status,
    super.effectiveFrom,
    super.endsOn,
    super.depots,
  });

  factory DepotAgreementModel.fromJson(DataMap json) {
    return DepotAgreementModel(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      kind: json['kind'] as String? ?? 'onInvoice',
      status: json['status'] as String? ?? 'Active',
      effectiveFrom: json['effectiveFrom'] != null
          ? DateTime.tryParse(json['effectiveFrom'] as String)
          : null,
      endsOn: json['endsOn'] != null
          ? DateTime.tryParse(json['endsOn'] as String)
          : null,
      depots: json['customers'] as String?,
    );
  }
}

class DiscountAuthorityModel extends DiscountAuthority {
  const DiscountAuthorityModel({
    required super.level,
    required super.roleName,
    required super.maxManualDiscountPercent,
    required super.lineDiscountCapPercent,
    required super.currency,
    required super.suggestedChips,
  });

  factory DiscountAuthorityModel.fromJson(DataMap json) {
    final rawChips = json['suggestedChips'] as List<dynamic>? ?? const [];
    final chips = rawChips.whereType<num>().map((n) => n.toDouble()).toList();

    return DiscountAuthorityModel(
      level: json['level'] as int? ?? 1,
      roleName: json['roleName'] as String? ?? 'Sales Representative',
      maxManualDiscountPercent:
          (json['maxManualDiscountPercent'] as num?)?.toDouble() ?? 3.0,
      lineDiscountCapPercent:
          (json['lineDiscountCapPercent'] as num?)?.toDouble() ?? 7.0,
      currency: json['currency'] as String? ?? 'US3',
      suggestedChips:
          chips.isNotEmpty ? chips : const [0.5, 1.0, 1.5, 2.0, 2.5, 3.0],
    );
  }
}
