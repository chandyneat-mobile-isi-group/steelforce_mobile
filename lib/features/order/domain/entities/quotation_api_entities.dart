import 'package:equatable/equatable.dart';

/// The 5 server-defined status groups matching `docs/feature/quotation-orders/api/mobile.md`.
enum QuotationStatusGroup {
  drafts('Drafts'),
  waiting('Waiting'),
  withDepot('WithDepot'),
  won('Won'),
  closed('Closed');

  const QuotationStatusGroup(this.wireName);
  final String wireName;

  static QuotationStatusGroup fromWire(String? value) {
    if (value == null) return QuotationStatusGroup.drafts;
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    for (final group in QuotationStatusGroup.values) {
      if (group.wireName.toLowerCase() == normalized) {
        return group;
      }
    }
    return QuotationStatusGroup.drafts;
  }
}

/// The 4 discount kinds declared in `docs/feature/quotation-orders/api/mobile.md`
/// and `docs/feature/prom-discount/integration-points.md`.
enum QuotationDiscountKind {
  manual(0),
  agreement(1),
  pickup(2),
  campaign(3);

  const QuotationDiscountKind(this.value);
  final int value;

  static QuotationDiscountKind fromValue(dynamic val) {
    if (val is int) {
      for (final kind in QuotationDiscountKind.values) {
        if (kind.value == val) return kind;
      }
    } else if (val is String) {
      final s = val.toLowerCase();
      if (s == 'agreement') return QuotationDiscountKind.agreement;
      if (s == 'pickup') return QuotationDiscountKind.pickup;
      if (s == 'campaign') return QuotationDiscountKind.campaign;
    }
    return QuotationDiscountKind.manual;
  }
}

/// A summary row returned by `GET /api/v1/mobile/quotations`.
class QuotationSummary extends Equatable {
  const QuotationSummary({
    required this.id,
    required this.number,
    required this.depotId,
    required this.depotName,
    required this.status,
    required this.statusGroup,
    required this.net,
    required this.lineCount,
    required this.createdAt,
    this.currency,
    this.validTo,
    this.updatedAt,
  });

  final String id;
  final String number;
  final String depotId;
  final String depotName;
  final String status;
  final QuotationStatusGroup statusGroup;
  final String? currency;
  final double net;
  final int lineCount;
  final DateTime? validTo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        id,
        number,
        depotId,
        depotName,
        status,
        statusGroup,
        currency,
        net,
        lineCount,
        validTo,
        createdAt,
        updatedAt,
      ];
}

/// Detailed quotation returned by `GET /api/v1/mobile/quotations/{id}`.
class QuotationDetail extends Equatable {
  const QuotationDetail({
    required this.id,
    required this.number,
    required this.depotId,
    required this.depotName,
    required this.status,
    required this.statusGroup,
    required this.shipmentType,
    required this.lines,
    required this.totals,
    required this.revision,
    required this.requiredApprovalLevel,
    this.currency,
    this.shipTo,
    this.paymentTerm,
    this.depotReference,
    this.remarks,
    this.decisionReason,
    this.validFrom,
    this.validTo,
    this.submittedAt,
    this.decidedAt,
    this.decidedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String number;
  final String depotId;
  final String? depotName;
  final String status;
  final QuotationStatusGroup statusGroup;
  final String shipmentType;
  final String? shipTo;
  final String? paymentTerm;
  final String? depotReference;
  final String? remarks;
  final String? currency;
  final List<QuotationLineItem> lines;
  final QuotationTotals totals;
  final int revision;
  final int requiredApprovalLevel;
  final String? decisionReason;
  final DateTime? validFrom;
  final DateTime? validTo;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEditable =>
      status.toLowerCase() == 'draft' || status.toLowerCase() == 'returned';

  bool get isPendingApproval => status.toLowerCase() == 'pendingapproval';

  @override
  List<Object?> get props => [
        id,
        number,
        depotId,
        depotName,
        status,
        statusGroup,
        shipmentType,
        shipTo,
        paymentTerm,
        depotReference,
        remarks,
        currency,
        lines,
        totals,
        revision,
        requiredApprovalLevel,
        decisionReason,
        validFrom,
        validTo,
        submittedAt,
        decidedAt,
        decidedBy,
        createdAt,
        updatedAt,
      ];
}

/// A quotation line item with snapshot pricing and discount rows.
class QuotationLineItem extends Equatable {
  const QuotationLineItem({
    required this.id,
    required this.lineNumber,
    required this.materialNumber,
    required this.materialDescription,
    required this.quantity,
    required this.unit,
    required this.priceAmount,
    required this.priceCurrency,
    required this.pricePricingUnit,
    required this.priceConditionUnit,
    required this.discounts,
    required this.gross,
    required this.discountTotal,
    required this.net,
    this.category,
  });

  final String id;
  final int lineNumber;
  final String materialNumber;
  final String materialDescription;
  final double quantity;
  final String unit;
  final double priceAmount;
  final String priceCurrency;
  final double pricePricingUnit;
  final String priceConditionUnit;
  final List<QuotationLineDiscount> discounts;
  final double gross;
  final double discountTotal;
  final double net;
  final String? category;

  /// Effective unit price display: e.g. "0.475 US3 / KG" or "47.50 US3 / 100 KG"
  String get formattedPrice {
    final unitPrefix =
        pricePricingUnit != 1 ? '${pricePricingUnit.toStringAsFixed(0)} ' : '';
    return '${priceAmount.toStringAsFixed(3)} $priceCurrency / $unitPrefix$priceConditionUnit';
  }

  /// Discretionary rep manual discount if present
  QuotationLineDiscount? get manualDiscount {
    for (final d in discounts) {
      if (d.kind == QuotationDiscountKind.manual) return d;
    }
    return null;
  }

  /// Agreement discounts if present
  List<QuotationLineDiscount> get agreementDiscounts {
    return discounts
        .where((d) => d.kind == QuotationDiscountKind.agreement)
        .toList();
  }

  @override
  List<Object?> get props => [
        id,
        lineNumber,
        materialNumber,
        materialDescription,
        quantity,
        unit,
        priceAmount,
        priceCurrency,
        pricePricingUnit,
        priceConditionUnit,
        discounts,
        gross,
        discountTotal,
        net,
        category,
      ];
}

/// A discount row on a quotation line item.
class QuotationLineDiscount extends Equatable {
  const QuotationLineDiscount({
    required this.id,
    required this.kind,
    required this.percent,
    required this.editable,
    this.sourceReference,
    this.sapConditionType,
    this.estimateAmount,
    this.sapAmount,
  });

  final String id;
  final QuotationDiscountKind kind;
  final double percent;
  final bool editable;
  final String? sourceReference;
  final String? sapConditionType;
  final double? estimateAmount;
  final double? sapAmount;

  @override
  List<Object?> get props => [
        id,
        kind,
        percent,
        editable,
        sourceReference,
        sapConditionType,
        estimateAmount,
        sapAmount,
      ];
}

/// Totals block returned by preview and quotation detail endpoints.
class QuotationTotals extends Equatable {
  const QuotationTotals({
    required this.currency,
    required this.gross,
    required this.discountTotal,
    required this.net,
    required this.isEstimate,
    this.tax,
  });

  final String currency;
  final double gross;
  final double discountTotal;
  final double net;
  final bool isEstimate;
  final double? tax;

  @override
  List<Object?> get props =>
      [currency, gross, discountTotal, net, isEstimate, tax];
}

/// Warning item in quotation preview.
class QuotationWarning extends Equatable {
  const QuotationWarning({
    required this.code,
    this.lineId,
    this.message,
  });

  final String code;
  final String? lineId;
  final String? message;

  @override
  List<Object?> get props => [code, lineId, message];
}

/// Full preview data from `GET /api/v1/mobile/quotations/{id}/preview`.
class QuotationPreviewData extends Equatable {
  const QuotationPreviewData({
    required this.quotationId,
    required this.lines,
    required this.totals,
    required this.warnings,
    required this.manualDiscountLimitPercent,
    required this.lineDiscountCapPercent,
    required this.requiredApprovalLevel,
  });

  final String quotationId;
  final List<QuotationLineItem> lines;
  final QuotationTotals totals;
  final List<QuotationWarning> warnings;
  final double manualDiscountLimitPercent;
  final double lineDiscountCapPercent;
  final int requiredApprovalLevel;

  @override
  List<Object?> get props => [
        quotationId,
        lines,
        totals,
        warnings,
        manualDiscountLimitPercent,
        lineDiscountCapPercent,
        requiredApprovalLevel,
      ];
}

/// Approval record for history trail.
class QuotationApprovalHistory extends Equatable {
  const QuotationApprovalHistory({
    required this.id,
    required this.action,
    required this.createdAt,
    this.actorId,
    this.actorName,
    this.comment,
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final String? actorId;
  final String? actorName;
  final String? comment;

  @override
  List<Object?> get props =>
      [id, action, createdAt, actorId, actorName, comment];
}

/// Depot depot standing agreement model.
class DepotAgreement extends Equatable {
  const DepotAgreement({
    required this.id,
    required this.category,
    required this.percent,
    required this.kind,
    required this.status,
    this.effectiveFrom,
    this.endsOn,
    this.depots,
  });

  final String id;
  final String category;
  final double percent;
  final String kind;
  final String status;
  final DateTime? effectiveFrom;
  final DateTime? endsOn;
  final String? depots;

  @override
  List<Object?> get props => [
        id,
        category,
        percent,
        kind,
        status,
        effectiveFrom,
        endsOn,
        depots,
      ];
}

/// Request DTO for setting manual line discounts.
class QuotationDiscountIntent extends Equatable {
  const QuotationDiscountIntent({
    required this.lineId,
    required this.percent,
    this.reason,
  });

  final String lineId;
  final double percent;
  final String? reason;

  Map<String, dynamic> toJson() => {
        'lineId': lineId,
        'percent': percent,
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
      };

  @override
  List<Object?> get props => [lineId, percent, reason];
}

/// Representative line discount authority and suggested chips.
class DiscountAuthority extends Equatable {
  const DiscountAuthority({
    required this.level,
    required this.roleName,
    required this.maxManualDiscountPercent,
    required this.lineDiscountCapPercent,
    required this.currency,
    required this.suggestedChips,
  });

  final int level;
  final String roleName;
  final double maxManualDiscountPercent;
  final double lineDiscountCapPercent;
  final String currency;
  final List<double> suggestedChips;

  @override
  List<Object?> get props => [
        level,
        roleName,
        maxManualDiscountPercent,
        lineDiscountCapPercent,
        currency,
        suggestedChips,
      ];
}
