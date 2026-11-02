import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_api_repository.dart';
import 'package:steelforce/features/order/practice/order_practice_data.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// The Admin backend's quotation API during practice, answered from
/// [OrderPracticeData] — no request leaves the device.
///
/// Behaves like a small, well-mannered backend: drafts are editable, lines are
/// priced from the demo catalog with totals that add up, submitting a draft
/// moves it to `PendingApproval`, and anything not editable refuses to change.
/// Once [PracticeWorld.isClosed] every call goes to [_real].
class PracticeQuotationApiRepository implements QuotationApiRepository {
  PracticeQuotationApiRepository({
    required QuotationApiRepository real,
    required PracticeWorld world,
    required OrderPracticeData data,
  })  : _real = real,
        _world = world,
        _data = data;

  final QuotationApiRepository _real;
  final PracticeWorld _world;
  final OrderPracticeData _data;

  bool get _live => _world.isClosed;

  static const manualDiscountLimitPercent = 10.0;
  static const lineDiscountCapPercent = 15.0;

  static const _notFound = ServerFailure(
      message: 'orders.quotation.error.not_found', statusCode: 404);
  static const _notEditable = ServerFailure(
    message: 'orders.quotation.error.not_editable',
    statusCode: 409,
    code: 'Quotation.NotEditable',
  );

  // ── Reads ───────────────────────────────────────────────────────────

  @override
  ResultFuture<PagedResult<QuotationSummary>> getQuotations({
    String? status,
    String? depotId,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (_live) {
      return _real.getQuotations(
          status: status, depotId: depotId, page: page, pageSize: pageSize);
    }
    final wanted = status?.toLowerCase();
    final matching = _data.details.values
        .where((d) =>
            (depotId == null || d.depotId == depotId) &&
            (wanted == null ||
                d.status.toLowerCase() == wanted ||
                d.statusGroup.wireName.toLowerCase() == wanted))
        .toList()
      ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0))
          .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0)));
    final start = (page - 1) * pageSize;
    final slice = start >= matching.length
        ? const <QuotationDetail>[]
        : matching.skip(start).take(pageSize).toList();
    return Success(PagedResult(
      items: [for (final d in slice) _summary(d)],
      page: page,
      hasMore: start + slice.length < matching.length,
    ));
  }

  @override
  ResultFuture<QuotationDetail> getQuotationDetail(String id) async {
    if (_live) return _real.getQuotationDetail(id);
    final detail = _data.details[id];
    return detail == null ? const Failed(_notFound) : Success(detail);
  }

  @override
  ResultFuture<QuotationPreviewData> getPreview(String id) async {
    if (_live) return _real.getPreview(id);
    final detail = _data.details[id];
    if (detail == null) return const Failed(_notFound);
    return Success(QuotationPreviewData(
      quotationId: detail.id,
      lines: detail.lines,
      totals: detail.totals,
      warnings: const [],
      manualDiscountLimitPercent: manualDiscountLimitPercent,
      lineDiscountCapPercent: lineDiscountCapPercent,
      requiredApprovalLevel: detail.requiredApprovalLevel,
    ));
  }

  @override
  ResultFuture<List<QuotationApprovalHistory>> getHistory(String id) async {
    if (_live) return _real.getHistory(id);
    if (!_data.details.containsKey(id)) return const Failed(_notFound);
    return Success(List.unmodifiable(_data.history[id] ?? const []));
  }

  @override
  ResultFuture<List<DepotAgreement>> getDepotAgreements(String depotId) async {
    if (_live) return _real.getDepotAgreements(depotId);
    return const Success(<DepotAgreement>[]);
  }

  @override
  ResultFuture<List<PromoGroup>> getDepotIncentives(String depotId,
      {String? shipment}) async {
    if (_live) return _real.getDepotIncentives(depotId, shipment: shipment);
    return const Success(<PromoGroup>[]);
  }

  @override
  ResultFuture<List<PromoView>> getDepotPromotions(String depotId) async {
    if (_live) return _real.getDepotPromotions(depotId);
    return const Success(<PromoView>[]);
  }

  @override
  ResultFuture<DiscountAuthority> getDiscountAuthority() async {
    if (_live) return _real.getDiscountAuthority();
    return const Success(DiscountAuthority(
      level: 1,
      roleName: 'Sales Representative',
      maxManualDiscountPercent: manualDiscountLimitPercent,
      lineDiscountCapPercent: lineDiscountCapPercent,
      currency: OrderPracticeData.currency,
      suggestedChips: [2, 5, 10],
    ));
  }

  // ── Writes ──────────────────────────────────────────────────────────

  @override
  ResultFuture<QuotationDetail> createQuotation({
    required String depotId,
    String shipmentType = 'Pickup',
    String? shipTo,
  }) async {
    if (_live) {
      return _real.createQuotation(
          depotId: depotId, shipmentType: shipmentType, shipTo: shipTo);
    }
    return Success(_data.newDraft(
        depotId: depotId, shipmentType: shipmentType, shipTo: shipTo));
  }

  @override
  ResultFuture<QuotationDetail> updateQuotationHeader(
    String id, {
    required String shipmentType,
    String? shipTo,
    String? paymentTerm,
    String? depotReference,
    String? remarks,
  }) async {
    if (_live) {
      return _real.updateQuotationHeader(id,
          shipmentType: shipmentType,
          shipTo: shipTo,
          paymentTerm: paymentTerm,
          depotReference: depotReference,
          remarks: remarks);
    }
    return _editDraft(
      id,
      (d) => _data.copyDetail(
        d,
        shipmentType: shipmentType,
        shipTo: () => shipTo,
        paymentTerm: () => paymentTerm,
        depotReference: () => depotReference,
        remarks: () => remarks,
      ),
    );
  }

  @override
  ResultFuture<QuotationDetail> addLine(
    String id, {
    required String materialNumber,
    required double quantity,
    String? unit,
  }) async {
    if (_live) {
      return _real.addLine(id,
          materialNumber: materialNumber, quantity: quantity, unit: unit);
    }
    return _editDraft(id, (d) {
      final next =
          d.lines.fold<int>(0, (m, l) => l.lineNumber > m ? l.lineNumber : m) +
              1;
      return _data.withLines(d, [
        ...d.lines,
        OrderPracticeData.line(
          id: '${d.id}-l$next',
          lineNumber: next,
          material: materialNumber,
          quantity: quantity,
          unit: unit,
        ),
      ]);
    });
  }

  @override
  ResultFuture<QuotationDetail> updateLine(
    String id,
    String lineId, {
    required double quantity,
    String? unit,
  }) async {
    if (_live) {
      return _real.updateLine(id, lineId, quantity: quantity, unit: unit);
    }
    return _editDraft(id, (d) {
      if (!d.lines.any((l) => l.id == lineId)) return null;
      return _data.withLines(d, [
        for (final l in d.lines)
          if (l.id == lineId)
            _reprice(l, quantity: quantity, unit: unit ?? l.unit)
          else
            l,
      ]);
    });
  }

  @override
  ResultFuture<QuotationDetail> deleteLine(String id, String lineId) async {
    if (_live) return _real.deleteLine(id, lineId);
    return _editDraft(id, (d) {
      if (!d.lines.any((l) => l.id == lineId)) return null;
      return _data.withLines(d, [
        for (final l in d.lines)
          if (l.id != lineId) l
      ]);
    });
  }

  @override
  ResultFuture<QuotationDetail> setDiscounts(
    String id, {
    required List<QuotationDiscountIntent> lines,
  }) async {
    if (_live) return _real.setDiscounts(id, lines: lines);
    final byLine = {for (final i in lines) i.lineId: i.percent};
    return _editDraft(
      id,
      (d) => _data.withLines(d, [
        for (final l in d.lines)
          if (byLine.containsKey(l.id))
            _reprice(l,
                discountPercent: byLine[l.id]!
                    .clamp(0, manualDiscountLimitPercent)
                    .toDouble())
          else
            l,
      ]),
    );
  }

  @override
  ResultFuture<QuotationDetail> reprice(String id) async {
    if (_live) return _real.reprice(id);
    final detail = _data.details[id];
    if (detail == null) return const Failed(_notFound);
    // Demo prices never move, so a reprice is the same document re-read.
    return Success(detail);
  }

  @override
  ResultFuture<QuotationDetail> submit(String id) async {
    if (_live) return _real.submit(id);
    final detail = _data.details[id];
    if (detail == null) return const Failed(_notFound);
    if (!detail.isEditable) return const Failed(_notEditable);
    if (detail.lines.isEmpty) {
      return const Failed(ServerFailure(
        message: 'orders.quotation.error.no_lines',
        statusCode: 422,
        code: 'Quotation.NoLines',
      ));
    }
    final submitted = _data.copyDetail(
      detail,
      status: 'PendingApproval',
      statusGroup: QuotationStatusGroup.waiting,
      submittedAt: _data.now,
    );
    _data.details[id] = submitted;
    _record(id, 'Submitted');
    return Success(submitted);
  }

  @override
  ResultFuture<QuotationDetail> cancel(String id) async {
    if (_live) return _real.cancel(id);
    final detail = _data.details[id];
    if (detail == null) return const Failed(_notFound);
    if (!detail.isEditable && !detail.isPendingApproval) {
      return const Failed(_notEditable);
    }
    final cancelled = _data.copyDetail(
      detail,
      status: 'Cancelled',
      statusGroup: QuotationStatusGroup.closed,
    );
    _data.details[id] = cancelled;
    _record(id, 'Cancelled');
    return Success(cancelled);
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Applies [change] to an editable draft and stores the result. [change]
  /// returning null means the line it was asked about does not exist.
  Result<QuotationDetail> _editDraft(
    String id,
    QuotationDetail? Function(QuotationDetail draft) change,
  ) {
    final detail = _data.details[id];
    if (detail == null) return const Failed(_notFound);
    if (!detail.isEditable) return const Failed(_notEditable);
    final updated = change(detail);
    if (updated == null) {
      return const Failed(ServerFailure(
          message: 'orders.quotation.error.line_not_found', statusCode: 404));
    }
    _data.details[id] = updated;
    return Success(updated);
  }

  QuotationLineItem _reprice(
    QuotationLineItem l, {
    double? quantity,
    String? unit,
    double? discountPercent,
  }) =>
      OrderPracticeData.line(
        id: l.id,
        lineNumber: l.lineNumber,
        material: l.materialNumber,
        quantity: quantity ?? l.quantity,
        unit: unit ?? l.unit,
        manualDiscountPercent:
            discountPercent ?? l.manualDiscount?.percent ?? 0,
      );

  void _record(String id, String action) {
    final trail = _data.history.putIfAbsent(id, () => []);
    trail.add(QuotationApprovalHistory(
      id: '$id-h${trail.length + 1}',
      action: action,
      createdAt: _data.now(),
    ));
  }

  static QuotationSummary _summary(QuotationDetail d) => QuotationSummary(
        id: d.id,
        number: d.number,
        depotId: d.depotId,
        depotName: d.depotName ?? d.depotId,
        status: d.status,
        statusGroup: d.statusGroup,
        currency: d.currency,
        net: d.totals.net,
        lineCount: d.lines.length,
        validTo: d.validTo,
        createdAt: d.createdAt ?? DateTime(0),
        updatedAt: d.updatedAt,
      );
}
