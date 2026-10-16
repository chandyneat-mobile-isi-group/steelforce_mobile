import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_remote_data_source.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_store.dart';
import 'package:steelforce/features/order/data/services/api_quotation_admin_gateway.dart';
import 'package:steelforce/features/order/domain/entities/admin_submit_result.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/services/sync_queue_processor.dart';

import '../../admin_sync/admin_sync_fakes.dart';

/// The processor's view of reachability in a demo build, as `NetworkInfo`
/// would answer it from `DemoReachabilityProbe`.
class _DemoNetworkInfo implements NetworkInfo {
  _DemoNetworkInfo(this._demo);
  final DemoNetwork _demo;
  @override
  Future<bool> get isConnected async => _demo.isOnline;
}

CartItem _item(String material, double quantity, String unit,
        {double discount = 0}) =>
    CartItem(
      id: 'L-$material',
      product: product(material),
      quantity: quantity,
      unit: unit,
      discountPercent: discount,
    );

void main() {
  late DemoNetwork demo;
  late DemoQuotationRemoteDataSource backend;
  late InMemorySyncQueue queue;
  late FakeQuotationRepository quotations;
  late SyncQueueProcessor processor;

  final depot = DemoSeed.depots[1];

  setUp(() {
    demo = DemoNetwork();
    backend = DemoQuotationRemoteDataSource(
        demo, DemoQuotationStore(DemoMaterialBook()));
    queue = InMemorySyncQueue();
    quotations = FakeQuotationRepository();
    processor = SyncQueueProcessor(
      queue: queue,
      quotations: quotations,
      gateway: ApiQuotationAdminGateway(backend),
      network: _DemoNetworkInfo(demo),
      currentUserId: () => DemoSeed.repId,
    );
    quotations.byId['QT-local-1'] = quotation(
      id: 'QT-local-1',
      depotId: depot.id,
      lines: [
        _item('2400001024', 120, 'M', discount: 1),
        _item('2400002043', 40, 'M'),
      ],
    );
  });

  test(
      'a quotation saved offline waits, then reaches Admin Review on '
      'reconnect', () async {
    demo.setOnline(false);
    await queue.enqueue('QT-local-1', ownerUserId: DemoSeed.repId);

    await processor.processAll();
    var item = queue.byQuotation['QT-local-1']!;
    expect(item.status, QuotationSyncStatus.pendingSync);
    expect(item.attemptCount, 0);

    demo.setOnline(true);
    await processor.processAll();

    item = queue.byQuotation['QT-local-1']!;
    expect(item.status, QuotationSyncStatus.accepted);
    expect(item.remoteStatus, 'PendingApproval');
    expect(item.remoteNumber, matches(RegExp(r'^Q-\d{4}-\d{4}$')));
    expect(quotations.byId['QT-local-1']!.remoteId, item.remoteQuotationId);

    final doc = await backend.fetchQuotationById(item.remoteQuotationId!);
    expect(doc.depotId, depot.id);
    expect(doc.lines.map((l) => l.materialNumber).toSet(),
        {'2400001024', '2400002043'});
    expect(
        doc.lines
            .firstWhere((l) => l.materialNumber == '2400001024')
            .manualDiscount!
            .percent,
        1);

    // The review poll recognises it as still in review.
    await processor.refreshReviews();
    expect(
        queue.byQuotation['QT-local-1']!.status, QuotationSyncStatus.accepted);
  });

  test('a push interrupted by going offline retries without duplicating',
      () async {
    await queue.enqueue('QT-local-1', ownerUserId: DemoSeed.repId);
    final before =
        (await backend.fetchQuotations(pageSize: 100)).metadata!.totalRecords;

    // Online for the create, offline before the lines go up.
    final gateway = ApiQuotationAdminGateway(backend);
    final first = await gateway.submit(
      quotations.byId['QT-local-1']!,
      remoteId: null,
      onRemoteCreated: (id) async => demo.setOnline(false),
    );
    expect(first, isA<AdminTransportFailure>());

    demo.setOnline(true);
    await processor.processAll();
    final item = queue.byQuotation['QT-local-1']!;
    expect(item.status, QuotationSyncStatus.accepted);
    final after =
        (await backend.fetchQuotations(pageSize: 100)).metadata!.totalRecords;
    expect(after, before + 1);
  });

  test('after an app restart a synced quotation still reads as in review',
      () async {
    await queue.enqueue('QT-local-1', ownerUserId: DemoSeed.repId);
    await processor.processAll();
    final remoteId = queue.byQuotation['QT-local-1']!.remoteQuotationId!;

    // A fresh demo backend: the in-memory store is gone, the queue is not.
    final restarted = SyncQueueProcessor(
      queue: queue,
      quotations: quotations,
      gateway: ApiQuotationAdminGateway(DemoQuotationRemoteDataSource(
          demo, DemoQuotationStore(DemoMaterialBook()))),
      network: _DemoNetworkInfo(demo),
      currentUserId: () => DemoSeed.repId,
    );
    await restarted.refreshReviews();

    final item = queue.byQuotation['QT-local-1']!;
    expect(item.remoteQuotationId, remoteId);
    expect(item.status, QuotationSyncStatus.accepted);
  });
}
