import 'dart:async';

import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';

/// The whole Orders world of one practice run, in memory.
///
/// Every order stand-in reads and writes here and nowhere else, so a lesson
/// sees one coherent set of documents: the quotation the builder saved is the
/// one the detail screen submits, the approved demo quotation the Orders tab
/// lists is the one the sales-order screen converts.
///
/// Dropped with the practice scope — nothing in it is ever persisted.
class OrderPracticeData {
  OrderPracticeData({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _seed();
  }

  final DateTime Function() _clock;
  DateTime now() => _clock();

  /// VAT applied to every practice document, matching the 10% the real local
  /// repositories and the builder use.
  static const taxRate = 0.10;
  static const currency = 'USD';

  // ── Stores ──────────────────────────────────────────────────────────

  /// The practice cart. The rep's real cart is never read or written.
  final List<CartItem> cart = [];

  /// Local (device) quotations, by id, in insertion order.
  final Map<String, Quotation> quotations = {};

  /// Server (Admin backend) quotations, by id.
  final Map<String, QuotationDetail> details = {};

  /// Approval trail per server quotation id.
  final Map<String, List<QuotationApprovalHistory>> history = {};

  final Map<String, SalesOrder> salesOrders = {};

  final StreamController<List<Quotation>> _quotationChanges =
      StreamController<List<Quotation>>.broadcast();
  final StreamController<List<SalesOrder>> _salesOrderChanges =
      StreamController<List<SalesOrder>>.broadcast();

  Stream<List<Quotation>> get quotationChanges => _quotationChanges.stream;
  Stream<List<SalesOrder>> get salesOrderChanges => _salesOrderChanges.stream;

  void quotationsChanged() {
    if (!_quotationChanges.isClosed) {
      _quotationChanges.add(List.unmodifiable(quotations.values));
    }
  }

  void salesOrdersChanged() {
    if (!_salesOrderChanges.isClosed) {
      _salesOrderChanges.add(List.unmodifiable(salesOrders.values));
    }
  }

  Future<void> dispose() async {
    await _quotationChanges.close();
    await _salesOrderChanges.close();
  }

  int _sequence = 0;

  /// A fresh id carrying a `practice-` prefix ([PracticeIds]).
  String newId(String prefix) => '$prefix${++_sequence}';

  // ── Catalog and prices ──────────────────────────────────────────────

  /// The bundled ISI demo catalog — the same rows the mock catalog sync
  /// writes, read here straight from source so practice never touches the
  /// device database.
  static final List<Product> catalog = List.unmodifiable(
    IsiDemoCatalog.products().map(ProductModel.fromJson),
  );

  /// Small, predictable assortment shown by the order lesson in both remote
  /// and checked-in visit flows. Each item comes from a different steel family
  /// in the bundled ISI demo catalog; lesson orders still use the normal
  /// quotation and sales-order screens, but never need the live material API.
  static const practiceMaterialCategoryCode = 'practice-steel-materials';
  static const practiceMaterialStepKey = 'practice-material';
  static final List<Product> practiceMaterials = List.unmodifiable([
    for (final categoryId in const [
      IsiDemoCatalog.palmProfileCategoryId,
      IsiDemoCatalog.puPanelCategoryId,
      IsiDemoCatalog.giPipeCategoryId,
      IsiDemoCatalog.steelSheetCategoryId,
      IsiDemoCatalog.reinforcementCategoryId,
    ])
      catalog.firstWhere((product) => product.categoryId == categoryId),
  ]);

  static final Map<String, Product> _byMaterial = {
    for (final product in catalog) product.materialNumber: product,
  };

  static Product? productFor(String material) => _byMaterial[material.trim()];

  /// The demo price for [material]: the demo catalog's standard price when the
  /// material is in it, otherwise a stable figure derived from the material
  /// number, so a material the live finder returns is still priced in practice
  /// and prices the same every time it is shown.
  static double priceFor(String material) {
    final known = productFor(material)?.pricing.standardPrice;
    if (known != null && known > 0) return known;
    var hash = 0;
    for (final unit in material.trim().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    // 4.00 – 39.99 USD, two decimals.
    return (400 + hash % 3600) / 100;
  }

  // ── Server-document arithmetic ──────────────────────────────────────

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  /// One priced server line. Gross, discount and net are computed here the
  /// way the backend reports them, so the totals on screen always add up.
  static QuotationLineItem line({
    required String id,
    required int lineNumber,
    required String material,
    required double quantity,
    String? unit,
    double manualDiscountPercent = 0,
  }) {
    final product = productFor(material);
    final price = priceFor(material);
    final gross = _round(price * quantity);
    final discount = _round(gross * manualDiscountPercent / 100);
    final resolvedUnit =
        (unit == null || unit.isEmpty) ? (product?.unit ?? 'PCS') : unit;
    return QuotationLineItem(
      id: id,
      lineNumber: lineNumber,
      materialNumber: material,
      materialDescription: product?.name ?? material,
      quantity: quantity,
      unit: resolvedUnit,
      priceAmount: price,
      priceCurrency: currency,
      pricePricingUnit: 1,
      priceConditionUnit: resolvedUnit,
      discounts: [
        if (manualDiscountPercent > 0)
          QuotationLineDiscount(
            id: '$id-manual',
            kind: QuotationDiscountKind.manual,
            percent: manualDiscountPercent,
            editable: true,
            estimateAmount: discount,
          ),
      ],
      gross: gross,
      discountTotal: discount,
      net: _round(gross - discount),
      category: product?.categoryId,
    );
  }

  /// Totals over [lines]; `net` includes tax, as the builder reads it.
  static QuotationTotals totalsOf(List<QuotationLineItem> lines) {
    final gross = lines.fold<double>(0, (sum, l) => sum + l.gross);
    final discount = lines.fold<double>(0, (sum, l) => sum + l.discountTotal);
    final tax = _round((gross - discount) * taxRate);
    return QuotationTotals(
      currency: currency,
      gross: _round(gross),
      discountTotal: _round(discount),
      net: _round(gross - discount + tax),
      tax: tax,
      isEstimate: false,
    );
  }

  /// [detail] with [lines] and the totals they imply.
  QuotationDetail withLines(
          QuotationDetail detail, List<QuotationLineItem> lines) =>
      copyDetail(detail, lines: lines, totals: totalsOf(lines));

  QuotationDetail copyDetail(
    QuotationDetail d, {
    String? status,
    QuotationStatusGroup? statusGroup,
    String? shipmentType,
    String? Function()? shipTo,
    String? Function()? paymentTerm,
    String? Function()? depotReference,
    String? Function()? remarks,
    List<QuotationLineItem>? lines,
    QuotationTotals? totals,
    int? revision,
    DateTime? Function()? submittedAt,
  }) =>
      QuotationDetail(
        id: d.id,
        number: d.number,
        depotId: d.depotId,
        depotName: d.depotName,
        status: status ?? d.status,
        statusGroup: statusGroup ?? d.statusGroup,
        shipmentType: shipmentType ?? d.shipmentType,
        shipTo: shipTo != null ? shipTo() : d.shipTo,
        paymentTerm: paymentTerm != null ? paymentTerm() : d.paymentTerm,
        depotReference:
            depotReference != null ? depotReference() : d.depotReference,
        remarks: remarks != null ? remarks() : d.remarks,
        currency: d.currency,
        lines: lines ?? d.lines,
        totals: totals ?? d.totals,
        revision: revision ?? d.revision,
        requiredApprovalLevel: d.requiredApprovalLevel,
        decisionReason: d.decisionReason,
        validFrom: d.validFrom,
        validTo: d.validTo,
        submittedAt: submittedAt != null ? submittedAt() : d.submittedAt,
        decidedAt: d.decidedAt,
        decidedBy: d.decidedBy,
        createdAt: d.createdAt,
        updatedAt: now(),
      );

  /// A fresh server draft for [depotId].
  QuotationDetail newDraft({
    required String depotId,
    required String shipmentType,
    String? shipTo,
  }) {
    final id = newId(PracticeIds.quotationPrefix);
    final created = now();
    final draft = QuotationDetail(
      id: id,
      number: 'QT-PRACTICE-${id.substring(PracticeIds.quotationPrefix.length)}',
      depotId: depotId,
      depotName:
          depotId == PracticeIds.depotId ? PracticeIds.depotNameEn : null,
      status: 'Draft',
      statusGroup: QuotationStatusGroup.drafts,
      shipmentType: shipmentType,
      shipTo: shipTo,
      currency: currency,
      lines: const [],
      totals: totalsOf(const []),
      revision: 1,
      requiredApprovalLevel: 1,
      validFrom: created,
      validTo: created.add(const Duration(days: 14)),
      createdAt: created,
      updatedAt: created,
    );
    details[id] = draft;
    history[id] = [];
    return draft;
  }

  // ── Seed ────────────────────────────────────────────────────────────

  /// Seeds the one **approved** demo quotation the remote-order lesson converts:
  /// on the server side it is `Accepted` (which is what offers "Convert to
  /// Sales Order"), and on the device side it is the local copy that
  /// conversion actually reads its lines from.
  void _seed() {
    final created = now().subtract(const Duration(days: 2));
    final practiceQuantities = const [120.0, 12.0, 40.0, 30.0, 24.0];
    final picks = <({Product product, double quantity})>[
      for (final (index, product) in practiceMaterials.indexed)
        (product: product, quantity: practiceQuantities[index]),
    ];

    final items = [
      for (final (i, pick) in picks.indexed)
        CartItem(
          id: '${PracticeIds.approvedQuotationId}-line-${i + 1}',
          product: pick.product,
          quantity: pick.quantity,
          unit: pick.product.unit,
          discountPercent: 0,
          depotId: PracticeIds.depotId,
          unitPriceOverride: priceFor(pick.product.materialNumber),
        ),
    ];

    final serverLines = [
      for (final (i, item) in items.indexed)
        line(
          id: '${PracticeIds.approvedQuotationId}-l${i + 1}',
          lineNumber: i + 1,
          material: item.product.materialNumber,
          quantity: item.quantity,
          unit: item.unit,
        ),
    ];
    final totals = totalsOf(serverLines);

    details[PracticeIds.approvedQuotationId] = QuotationDetail(
      id: PracticeIds.approvedQuotationId,
      number: 'QT-PRACTICE-APPROVED',
      depotId: PracticeIds.depotId,
      depotName: PracticeIds.depotNameEn,
      status: 'Accepted',
      statusGroup: QuotationStatusGroup.won,
      shipmentType: 'Pickup',
      currency: currency,
      lines: serverLines,
      totals: totals,
      revision: 1,
      requiredApprovalLevel: 1,
      validFrom: created,
      validTo: created.add(const Duration(days: 14)),
      submittedAt: created,
      decidedAt: created.add(const Duration(hours: 3)),
      createdAt: created,
      updatedAt: created.add(const Duration(hours: 3)),
    );
    history[PracticeIds.approvedQuotationId] = [
      QuotationApprovalHistory(
        id: '${PracticeIds.approvedQuotationId}-h1',
        action: 'Submitted',
        createdAt: created,
      ),
      QuotationApprovalHistory(
        id: '${PracticeIds.approvedQuotationId}-h2',
        action: 'Approved',
        createdAt: created.add(const Duration(hours: 3)),
      ),
    ];

    quotations[PracticeIds.approvedQuotationId] = Quotation(
      id: PracticeIds.approvedQuotationId,
      depotId: PracticeIds.depotId,
      shopName: PracticeIds.depotNameEn,
      lines: items,
      subtotal: totals.gross,
      discount: totals.discountTotal,
      tax: totals.tax ?? 0,
      total: totals.net,
      status: QuotationStatus.saved,
      sapDraftStatus: 'Saved on device',
      validUntil: created.add(const Duration(days: 14)),
      createdAt: created,
      // "Now", so it sorts to the top of the Orders tab and is the row the
      // lesson points at.
      updatedAt: now(),
      remoteId: PracticeIds.approvedQuotationId,
    );
  }
}
