import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/mock/demo_api_errors.dart';
import 'package:steelforce/features/order/data/mock/demo_depot_commercial_fixtures.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_document.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_fixtures.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

/// The demo backend's quotation aggregate: every rule the live
/// `/mobile/quotations` surface enforces, held in memory.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// Refusals are the contract's own codes (`docs/feature/quotation-orders/
/// api/mobile.md`, "Every code this surface can return"), so the app's real
/// error handling is what a presenter sees.
///
/// ## Surviving an app restart
///
/// The store lives in memory; the device's sync queue does not. A quotation
/// pushed from the outbox is created under an id derived from its device id
/// (`dq-c-<clientId>`), so after a restart that id is still recognisable. It
/// answers as a document already in Admin Review rather than `404` — a `404`
/// would make the review poll mark every synced quotation as gone. It is
/// served by id only and kept out of the list, where an empty document would
/// mislead.
class DemoQuotationStore {
  DemoQuotationStore(this._book, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _docs.addAll(DemoQuotationFixtures.build(_clock()));
  }

  final DemoMaterialBook _book;
  final DateTime Function() _clock;
  final List<DemoQuotationDoc> _docs = [];
  var _sequence = DemoQuotationFixtures.firstNewSequence;
  var _ids = 0;

  static const _clientPrefix = 'dq-c-';

  ({List<DataMap> rows, int total}) list({
    String? status,
    String? depotId,
    required int page,
    required int pageSize,
  }) {
    final wanted = status?.trim().toLowerCase() ?? '';
    final rows = _docs.where((d) {
      if (wanted.isNotEmpty &&
          d.statusGroup.toLowerCase() != wanted &&
          d.status.toLowerCase() != wanted) {
        return false;
      }
      return depotId == null ||
          depotId.isEmpty ||
          d.depotId == depotId ||
          DemoSeed.depotById(depotId)?.id == d.depotId;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final start = (page - 1) * pageSize;
    return (
      rows:
          rows.skip(start).take(pageSize).map((d) => d.summaryJson()).toList(),
      total: rows.length,
    );
  }

  DemoQuotationDoc create(
      String depotId, String shipmentType, String? shipTo, String? clientId) {
    if (depotId.trim().isEmpty) throw DemoApiErrors.quotationNotFound();
    if (clientId != null) {
      final existing = _find('$_clientPrefix$clientId');
      if (existing != null) return existing;
    }
    final now = _clock();
    final doc = DemoQuotationDoc(
      id: clientId != null ? '$_clientPrefix$clientId' : 'dq-n-${++_ids}',
      number: DemoQuotationFixtures.number(now, _sequence++),
      depotId: DemoSeed.depotById(depotId)?.id ?? depotId,
      clientId: clientId,
      status: 'Draft',
      createdAt: now,
      shipmentType: shipmentType,
      shipTo: shipTo,
    );
    _docs.add(doc);
    _record(doc, 'Created');
    return doc;
  }

  DemoQuotationDoc get(String id) =>
      _find(id) ?? _ghost(id) ?? (throw DemoApiErrors.quotationNotFound());

  DemoQuotationDoc updateHeader(String id, DataMap header) {
    final doc = _editable(id);
    doc
      ..shipmentType = header['shipmentType'] as String? ?? 'Pickup'
      ..shipTo = header['shipTo'] as String?
      ..paymentTerm = header['paymentTerm'] as String?
      ..depotReference = header['depotReference'] as String?
      ..remarks = header['remarks'] as String?;
    return _touch(doc);
  }

  Future<DemoQuotationDoc> addLine(
      String id, String materialNumber, double quantity, String? unit) async {
    final doc = _editable(id);
    _checkQuantity(quantity);
    if (doc.lines.any((l) => l.material.number == materialNumber.trim())) {
      throw DemoApiErrors.of(422, 'Quotation.DuplicateLine');
    }
    final material = await _book.lookup(materialNumber);
    if (material == null) {
      throw DemoApiErrors.of(422, 'Quotation.MaterialNotPriced');
    }
    if (unit != null && unit.toUpperCase() != material.unit.toUpperCase()) {
      throw DemoApiErrors.of(422, 'Quotation.UnitMismatch',
          'Price is per ${material.unit}; received $unit.');
    }
    doc.lines.add(DemoQuotationLine(
      id: '${doc.id}-l${++_ids}',
      material: material,
      quantity: quantity,
      priceAmount: material.price,
      pricedAt: _clock(),
    ));
    return _touch(doc);
  }

  DemoQuotationDoc updateLine(String id, String lineId, double quantity) {
    final doc = _editable(id);
    _checkQuantity(quantity);
    _line(doc, lineId).quantity = quantity;
    return _touch(doc);
  }

  DemoQuotationDoc deleteLine(String id, String lineId) {
    final doc = _editable(id);
    doc.lines.remove(_line(doc, lineId));
    return _touch(doc);
  }

  /// Replaces the whole manual set: a line left out loses its discount.
  DemoQuotationDoc setDiscounts(
      String id, List<QuotationDiscountIntent> intents) {
    final doc = _editable(id);
    final wanted = <String, double>{};
    for (final intent in intents) {
      final line = _line(doc, intent.lineId);
      if (intent.percent < 0 || intent.percent > 100) {
        throw DemoApiErrors.of(422, 'Quotation.DiscountPercentInvalid');
      }
      if (doc.deductionPercent(line, intent.percent) >
          DemoDepotCommercial.lineCapPercent) {
        throw DemoApiErrors.of(422, 'Quotation.DiscountCapExceeded');
      }
      wanted[line.id] = intent.percent;
    }
    for (final line in doc.lines) {
      line.manualPercent = wanted[line.id] ?? 0;
    }
    return _touch(doc);
  }

  /// All-or-nothing: one unreadable price stops the whole repricing.
  Future<DemoQuotationDoc> reprice(String id) async {
    final doc = _editable(id);
    final current = await Future.wait(
        doc.lines.map((l) => _book.lookup(l.material.number)));
    if (current.any((m) => m == null)) {
      throw DemoApiErrors.of(502, 'Quotation.PriceUnavailable');
    }
    final now = _clock();
    for (var i = 0; i < doc.lines.length; i++) {
      doc.lines[i]
        ..priceAmount = current[i]!.price
        ..pricedAt = now;
    }
    _record(doc, 'Repriced');
    return _touch(doc);
  }

  Future<DemoQuotationDoc> submit(String id) async {
    final doc = _editable(id);
    if (doc.lines.isEmpty) throw DemoApiErrors.of(422, 'Quotation.NoLines');
    if (doc.shipmentType == 'Delivery' && (doc.shipTo ?? '').trim().isEmpty) {
      throw DemoApiErrors.of(422, 'Quotation.ShipToRequired');
    }
    for (final line in doc.lines) {
      final live = await _book.lookup(line.material.number);
      if (live == null) {
        throw DemoApiErrors.of(502, 'Quotation.PriceUnavailable');
      }
      if (live.price != line.priceAmount) {
        throw DemoApiErrors.of(409, 'Quotation.PriceChanged');
      }
    }
    doc
      ..status = 'PendingApproval'
      ..submittedAt = _clock()
      ..decisionReason = null;
    _record(doc, 'Submitted');
    return _touch(doc);
  }

  /// Withdraws a document still in the rep's hands or awaiting review.
  DemoQuotationDoc cancel(String id) {
    final doc = get(id);
    if (!doc.isEditable && doc.status != 'PendingApproval') {
      throw DemoApiErrors.invalidTransition(doc.status);
    }
    doc.status = 'Cancelled';
    _record(doc, 'Cancelled');
    return _touch(doc);
  }

  List<DataMap> history(String id) =>
      get(id).history.map((h) => h.toJson()).toList();

  DemoQuotationDoc? _find(String id) {
    for (final d in _docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  DemoQuotationDoc? _ghost(String id) {
    if (!id.startsWith(_clientPrefix)) return null;
    final now = _clock();
    return DemoQuotationDoc(
      id: id,
      number: DemoQuotationFixtures.number(now, 0),
      depotId: '',
      clientId: id.substring(_clientPrefix.length),
      status: 'PendingApproval',
      createdAt: now,
    );
  }

  DemoQuotationDoc _editable(String id) {
    final doc = get(id);
    if (!doc.isEditable) throw DemoApiErrors.notEditable(doc.status);
    return doc;
  }

  DemoQuotationLine _line(DemoQuotationDoc doc, String lineId) =>
      doc.line(lineId) ?? (throw DemoApiErrors.lineNotFound());

  void _checkQuantity(double quantity) {
    if (quantity <= 0) throw DemoApiErrors.of(422, 'Quotation.QuantityInvalid');
  }

  DemoQuotationDoc _touch(DemoQuotationDoc doc) {
    doc.updatedAt = _clock();
    return doc;
  }

  void _record(DemoQuotationDoc doc, String action) => doc.history.add(
        DemoHistoryEntry('${doc.id}-h${doc.history.length}', action, _clock(),
            actorName: DemoSeed.repName),
      );
}
