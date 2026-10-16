import 'dart:async';

import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/models/quotation_api_models.dart';
import 'package:steelforce/features/order/data/remote/quotation_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/product_status.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';

Product product(String materialCode) => Product(
      id: 'P-$materialCode',
      familyId: 'F1',
      familyName: 'Family',
      code: materialCode,
      sku: 'SKU-$materialCode',
      materialCode: materialCode,
      barcode: '',
      name: 'Material $materialCode',
      description: '',
      categoryId: 'roofing',
      subCategory: 'profile',
      brand: 'ISI',
      grade: 'SGCC',
      material: 'Steel',
      size: '',
      diameter: 0,
      thickness: 0,
      length: 0,
      width: 0,
      height: 0,
      weight: 0,
      unit: 'KG',
      warehouseCode: 'WH01',
      territory: 'PP',
      businessUnit: 'ISI',
      imageUrl: '',
      isMto: false,
      status: ProductStatus.active,
      updatedAt: DateTime(2026, 9, 1),
      pricing: ProductPricing.unpriced(),
      stockQuantity: 0,
      reservedQuantity: 0,
      minStock: 0,
      maxStock: 0,
    );

CartItem line(String material, double qty,
        {double discount = 0, bool customized = false}) =>
    CartItem(
      id: 'L-$material-$qty',
      product: product(material),
      quantity: qty,
      unit: 'KG',
      discountPercent: discount,
      isCustomized: customized,
    );

Quotation quotation({
  String id = 'QT-1',
  String? depotId = 'depot-1',
  List<CartItem>? lines,
  String? remoteId,
}) =>
    Quotation(
      id: id,
      depotId: depotId,
      lines: lines ?? [line('1500000017', 100)],
      subtotal: 0,
      discount: 0,
      tax: 0,
      total: 0,
      status: QuotationStatus.saved,
      sapDraftStatus: 'Saved on device',
      validUntil: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      remoteId: remoteId,
    );

ApiException apiError(int status, String code) =>
    ApiException(ApiError(code: code, statusCode: status, detail: code));

const offline = ApiException(ApiError(code: ApiErrorCodes.network));

class FakeLine {
  FakeLine(this.id, this.material, this.quantity, this.unit);
  final String id;
  final String material;
  double quantity;
  final String? unit;
  double manualPercent = 0;
}

class FakeDoc {
  FakeDoc(this.id, this.number, this.depotId);
  final String id;
  final String number;
  final String depotId;
  String status = 'Draft';
  String? decisionReason;
  final List<FakeLine> lines = [];
}

/// An in-memory Admin backend honouring the contract's shape: server-side
/// ids, `422 DuplicateLine`, submit moving a draft to `PendingApproval`.
class FakeAdminBackend implements QuotationRemoteDataSource {
  final Map<String, FakeDoc> docs = {};
  final Set<String> knownDepots = {'depot-1'};
  var _seq = 0;
  var createCalls = 0;
  var submitCalls = 0;
  var addLineCalls = 0;
  var setDiscountCalls = 0;
  var listCalls = 0;
  var detailCalls = 0;

  /// Throw on the next call to the named operation, then behave again.
  final Map<String, Object> failNext = {};
  bool down = false;

  void _gate(String op) {
    if (down) throw offline;
    final f = failNext.remove(op);
    if (f != null) throw f;
  }

  FakeDoc _doc(String id) {
    final d = docs[id];
    if (d == null) throw apiError(404, 'Quotation.NotFound');
    return d;
  }

  QuotationDetailModel _model(FakeDoc d) => QuotationDetailModel.fromJson({
        'id': d.id,
        'number': d.number,
        'customerId': d.depotId,
        'status': d.status,
        'decisionReason': d.decisionReason,
        'lines': [
          for (final l in d.lines)
            {
              'id': l.id,
              'materialNumber': l.material,
              'quantity': l.quantity,
              'unit': l.unit ?? 'KG',
              'discounts': [
                if (l.manualPercent > 0)
                  {
                    'id': 'D-${l.id}',
                    'kind': 0,
                    'percent': l.manualPercent,
                    'editable': true
                  },
              ],
            }
        ],
        'totals': const {'currency': 'US3'},
      });

  @override
  Future<QuotationDetailModel> createQuotation({
    required String depotId,
    String shipmentType = 'Pickup',
    String? shipTo,
    String? clientId,
  }) async {
    _gate('create');
    createCalls++;
    if (!knownDepots.contains(depotId)) {
      throw apiError(404, 'Quotation.NotFound');
    }
    final id = 'srv-${++_seq}';
    final d = FakeDoc(id, 'Q-2026-$_seq', depotId);
    docs[id] = d;
    return _model(d);
  }

  @override
  Future<QuotationDetailModel> fetchQuotationById(String id) async {
    _gate('detail');
    detailCalls++;
    return _model(_doc(id));
  }

  @override
  Future<QuotationDetailModel> addLine(String id,
      {required String materialNumber,
      required double quantity,
      String? unit}) async {
    _gate('addLine');
    addLineCalls++;
    final d = _doc(id);
    if (d.lines.any((l) => l.material == materialNumber)) {
      throw apiError(422, 'Quotation.DuplicateLine');
    }
    d.lines.add(FakeLine('ln-${++_seq}', materialNumber, quantity, unit));
    return _model(d);
  }

  @override
  Future<QuotationDetailModel> updateLine(String id, String lineId,
      {required double quantity, String? unit}) async {
    _gate('updateLine');
    final d = _doc(id);
    d.lines.firstWhere((l) => l.id == lineId).quantity = quantity;
    return _model(d);
  }

  @override
  Future<QuotationDetailModel> deleteLine(String id, String lineId) async {
    _gate('deleteLine');
    final d = _doc(id);
    d.lines.removeWhere((l) => l.id == lineId);
    return _model(d);
  }

  @override
  Future<QuotationDetailModel> setDiscounts(String id,
      {required List<QuotationDiscountIntent> lines}) async {
    _gate('discounts');
    setDiscountCalls++;
    final d = _doc(id);
    for (final l in d.lines) {
      l.manualPercent = 0;
    }
    for (final intent in lines) {
      d.lines.firstWhere((l) => l.id == intent.lineId).manualPercent =
          intent.percent;
    }
    return _model(d);
  }

  @override
  Future<QuotationDetailModel> submit(String id) async {
    _gate('submit');
    submitCalls++;
    final d = _doc(id);
    if (d.lines.isEmpty) throw apiError(422, 'Quotation.NoLines');
    d.status = 'PendingApproval';
    return _model(d);
  }

  @override
  Future<({List<QuotationSummaryModel> quotations, ApiMetadata? metadata})>
      fetchQuotations({
    String? status,
    String? depotId,
    int page = 1,
    int pageSize = 20,
  }) async {
    _gate('list');
    listCalls++;
    const waiting = {'PendingApproval', 'Approved', 'SubmittingToSap'};
    const drafts = {'Draft', 'Returned'};
    final rows = docs.values.where((d) => switch (status) {
          'Waiting' => waiting.contains(d.status),
          'Drafts' => drafts.contains(d.status),
          _ => true,
        });
    return (
      quotations: [
        for (final d in rows)
          QuotationSummaryModel.fromJson({
            'id': d.id,
            'number': d.number,
            'customerId': d.depotId,
            'customerName': 'Depot',
            'status': d.status,
            'lineCount': d.lines.length,
          })
      ],
      metadata: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeConnectivity implements ConnectivityService {
  final _changes = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _status = ConnectivityStatus.online;

  void set(ConnectivityStatus status) {
    _status = status;
    _changes.add(status);
  }

  @override
  ConnectivityStatus get status => _status;
  @override
  bool get isOnline => _status == ConnectivityStatus.online;
  @override
  Stream<ConnectivityStatus> get changes => _changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeNetwork implements NetworkInfo {
  bool online = true;
  @override
  Future<bool> get isConnected async => online;
}

/// The subset of [QuotationRepository] the processor uses, over a map.
class FakeQuotationRepository implements QuotationRepository {
  final Map<String, Quotation> byId = {};

  @override
  ResultFuture<Quotation?> getQuotationById(String id) async =>
      Success(byId[id]);

  @override
  Stream<List<Quotation>> watchQuotations() async* {
    yield byId.values.toList();
  }

  @override
  ResultFuture<void> deleteQuotation(String id) async {
    byId.remove(id);
    return const Success(null);
  }

  @override
  ResultFuture<void> linkRemote(String quotationId, String remoteId) async {
    final q = byId[quotationId];
    if (q == null) return const Failed(CacheFailure(message: 'missing'));
    byId[quotationId] = q.copyWith(remoteId: () => remoteId);
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// [SyncQueueRepository] over a list, with the same ownership rule as the DAO.
class InMemorySyncQueue implements SyncQueueRepository {
  final Map<String, SyncQueueItem> byQuotation = {};
  final _changes = StreamController<List<SyncQueueItem>>.broadcast();
  var _seq = 0;

  List<SyncQueueItem> get items => byQuotation.values.toList();

  @override
  Stream<List<SyncQueueItem>> watchQueue() async* {
    yield items;
    yield* _changes.stream;
  }

  void _emit() => _changes.add(items);

  @override
  Future<void> enqueue(String quotationId, {String? ownerUserId}) async {
    final now = DateTime.now();
    final existing = byQuotation[quotationId];
    byQuotation[quotationId] = existing == null
        ? SyncQueueItem(
            id: 'SQ-${++_seq}',
            quotationId: quotationId,
            status: QuotationSyncStatus.pendingSync,
            attemptCount: 0,
            createdAt: now,
            updatedAt: now,
            ownerUserId: ownerUserId,
          )
        : existing.copyWith(
            status: QuotationSyncStatus.pendingSync,
            attemptCount: 0,
            nextRetryAt: () => null,
            errorCode: () => null,
            decisionReason: () => null,
          );
    _emit();
  }

  bool _owned(SyncQueueItem i, String owner) =>
      i.ownerUserId == null || i.ownerUserId == owner;

  @override
  Future<List<SyncQueueItem>> readyItems(String ownerUserId) async => items
      .where((i) => i.isReady(DateTime.now()) && _owned(i, ownerUserId))
      .toList();

  @override
  Future<List<SyncQueueItem>> awaitingReview(String ownerUserId) async => items
      .where((i) =>
          (i.status == QuotationSyncStatus.accepted ||
              i.status == QuotationSyncStatus.conflict) &&
          i.remoteQuotationId != null &&
          _owned(i, ownerUserId) &&
          (i.remoteStatus == null ||
              const [
                'PendingApproval',
                'Approved',
                'SubmittingToSap',
                'SapFailed',
                'SubmittingOrder',
                'OrderFailed',
              ].contains(i.remoteStatus)))
      .toList();

  @override
  Future<void> save(SyncQueueItem item) async {
    byQuotation[item.quotationId] = item;
    _emit();
  }

  @override
  Future<void> remove(String quotationId) async {
    byQuotation.remove(quotationId);
    _emit();
  }

  @override
  Future<SyncQueueCounts> counts() async => const SyncQueueCounts();
}
