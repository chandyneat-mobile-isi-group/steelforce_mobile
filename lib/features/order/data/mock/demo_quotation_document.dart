import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/mock/demo_depot_commercial_fixtures.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';

/// One line of a demo quotation: the intent the rep sent (material, quantity,
/// manual discount) plus the price snapshot taken when it was added.
class DemoQuotationLine {
  DemoQuotationLine({
    required this.id,
    required this.material,
    required this.quantity,
    required this.priceAmount,
    required this.pricedAt,
    this.manualPercent = 0,
  });

  final String id;
  final DemoMaterial material;
  double quantity;
  double priceAmount;
  DateTime pricedAt;
  double manualPercent;
}

/// One row of the append-only approval trail.
class DemoHistoryEntry {
  const DemoHistoryEntry(this.id, this.action, this.at,
      {this.actorName, this.comment});

  final String id;
  final String action;
  final DateTime at;
  final String? actorName;
  final String? comment;

  DataMap toJson() => {
        'id': id,
        'action': action,
        'timestamp': at.toUtc().toIso8601String(),
        'actorName': actorName,
        'comment': comment,
      };
}

/// A demo quotation document and its wire rendering.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// The backend computes, the app transcribes (contract rule 1), so every money
/// figure is derived here, once, from the line intents:
/// `gross = quantity × price`; each discount row is `gross × percent`;
/// `net = gross − discountTotal`. `tax` is always null, as on the live
/// contract — SAP determines tax, and the field exists so no client invents
/// one. Amounts round to three decimals (`US3`).
class DemoQuotationDoc {
  DemoQuotationDoc({
    required this.id,
    required this.number,
    required this.depotId,
    required this.status,
    required this.createdAt,
    this.clientId,
    this.shipmentType = 'Pickup',
    this.shipTo,
    this.paymentTerm,
    this.depotReference,
    this.remarks,
    this.revision = 1,
  })  : updatedAt = createdAt,
        validFrom = createdAt,
        validTo = createdAt.add(const Duration(days: 15));

  final String id;
  final String number;
  final String depotId;
  final String? clientId;
  final DateTime createdAt;
  String status;
  String shipmentType;
  String? shipTo;
  String? paymentTerm;
  String? depotReference;
  String? remarks;
  int revision;
  String? decisionReason;
  DateTime validFrom;
  DateTime validTo;
  DateTime updatedAt;
  DateTime? submittedAt;
  DateTime? decidedAt;
  String? decidedBy;
  final List<DemoQuotationLine> lines = [];
  final List<DemoHistoryEntry> history = [];

  static const String currency = 'US3';

  static const Map<String, String> _groups = {
    'Draft': 'Drafts',
    'Returned': 'Drafts',
    'PendingApproval': 'Waiting',
    'Approved': 'Waiting',
    'SubmittingToSap': 'Waiting',
    'SapFailed': 'Waiting',
    'SubmittingOrder': 'Waiting',
    'OrderFailed': 'Waiting',
    'Quoted': 'WithDepot',
    'Accepted': 'Won',
    'Ordered': 'Won',
    'Rejected': 'Closed',
    'Cancelled': 'Closed',
    'Lost': 'Closed',
    'Expired': 'Closed',
  };

  static const Map<String, String> _displays = {
    'PendingApproval': 'Admin Review',
    'SubmittingToSap': 'Submitting to SAP',
    'Quoted': 'Submitted to SAP',
    'SapFailed': 'SAP submission failed',
  };

  static Set<String> get statuses => _groups.keys.toSet();
  static Set<String> get groups => _groups.values.toSet();

  String get statusGroup => _groups[status] ?? 'Drafts';
  bool get isEditable => status == 'Draft' || status == 'Returned';

  /// SAP has priced it — from `Quoted` on the figures are final.
  bool get _isEstimate =>
      !const {'Quoted', 'Accepted', 'Ordered'}.contains(status);

  DemoQuotationLine? line(String lineId) {
    for (final l in lines) {
      if (l.id == lineId) return l;
    }
    return null;
  }

  /// The approval level the manual discounts cost: within the rep's own
  /// authority is level 1, then one level per further two points.
  int get requiredApprovalLevel {
    final top = lines.fold<double>(
        0, (m, l) => l.manualPercent > m ? l.manualPercent : m);
    if (top <= DemoDepotCommercial.repAuthorityPercent) return 1;
    return top <= DemoDepotCommercial.repAuthorityPercent + 2 ? 2 : 3;
  }

  /// The line's total deduction if [manualPercent] were applied.
  double deductionPercent(DemoQuotationLine line, double manualPercent) =>
      (DemoDepotCommercial.agreementFor(depotId, line.material.categoryId)
              ?.percent ??
          0) +
      (shipmentType == 'Pickup' ? DemoDepotCommercial.pickupPercent : 0) +
      manualPercent;

  List<DataMap> linesJson() => [
        for (var i = 0; i < lines.length; i++) _lineJson(lines[i], i + 1),
      ];

  DataMap totalsJson() {
    var gross = 0.0, discount = 0.0;
    for (final l in linesJson()) {
      gross += l['gross'] as double;
      discount += l['discountTotal'] as double;
    }
    return {
      'currency': currency,
      'gross': _r3(gross),
      'discountTotal': _r3(discount),
      'net': _r3(gross - discount),
      'isEstimate': _isEstimate,
      'tax': null,
    };
  }

  DataMap summaryJson() => {
        'id': id,
        'number': number,
        'customerId': depotId,
        'customerName': DemoDepotCommercial.depotName(depotId),
        'status': status,
        'statusGroup': statusGroup,
        'statusDisplay': _displays[status] ?? status,
        'currency': lines.isEmpty ? null : currency,
        'net': totalsJson()['net'],
        'lineCount': lines.length,
        'validTo': validTo.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  DataMap detailJson() => {
        ...summaryJson(),
        'shipmentType': shipmentType,
        'shipTo': shipTo,
        'paymentTerm': paymentTerm,
        'customerReference': depotReference,
        'remarks': remarks,
        'lines': linesJson(),
        'totals': totalsJson(),
        'revision': revision,
        'requiredApprovalLevel': requiredApprovalLevel,
        'decisionReason': decisionReason,
        'validFrom': validFrom.toUtc().toIso8601String(),
        'submittedAt': submittedAt?.toUtc().toIso8601String(),
        'decidedAt': decidedAt?.toUtc().toIso8601String(),
        'decidedBy': decidedBy,
      };

  DataMap _lineJson(DemoQuotationLine line, int lineNumber) {
    final gross = _r3(line.quantity * line.priceAmount);
    final agreement =
        DemoDepotCommercial.agreementFor(depotId, line.material.categoryId);
    final discounts = <DataMap>[
      if (agreement != null)
        _discount(line, 'agr', 1, agreement.percent, gross, 'ZAG1',
            source: agreement.id),
      if (shipmentType == 'Pickup')
        _discount(
            line, 'pck', 2, DemoDepotCommercial.pickupPercent, gross, 'ZPCK'),
      if (line.manualPercent > 0)
        _discount(line, 'man', 0, line.manualPercent, gross, 'ZMAN',
            editable: true),
    ];
    final discountTotal = _r3(discounts.fold<double>(
        0, (s, d) => s + (d['estimateAmount'] as double)));
    return {
      'id': line.id,
      'lineNumber': lineNumber,
      'materialNumber': line.material.number,
      'materialDescription': line.material.description,
      'quantity': line.quantity,
      'unit': line.material.unit,
      'price': {
        'amount': line.priceAmount,
        'currency': currency,
        'pricingUnit': 1,
        'conditionUnit': line.material.unit,
      },
      'discounts': discounts,
      'gross': gross,
      'discountTotal': discountTotal,
      'net': _r3(gross - discountTotal),
      'category': line.material.categoryName,
    };
  }

  DataMap _discount(DemoQuotationLine line, String suffix, int kind,
      double percent, double gross, String condition,
      {bool editable = false, String? source}) {
    final amount = _r3(gross * percent / 100);
    return {
      'id': '${line.id}-$suffix',
      'kind': kind,
      'percent': percent,
      'editable': editable,
      'sourceReference': source,
      'sapConditionType': condition,
      'estimateAmount': amount,
      if (!_isEstimate) 'sapAmount': amount,
    };
  }

  static double _r3(double v) => (v * 1000).roundToDouble() / 1000;
}
