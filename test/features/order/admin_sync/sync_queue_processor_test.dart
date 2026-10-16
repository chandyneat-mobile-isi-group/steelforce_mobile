import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/data/services/api_quotation_admin_gateway.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/services/sync_queue_processor.dart';

import 'admin_sync_fakes.dart';

void main() {
  late FakeAdminBackend backend;
  late InMemorySyncQueue queue;
  late FakeQuotationRepository quotations;
  late FakeNetwork network;
  String? user;
  late SyncQueueProcessor processor;

  setUp(() {
    backend = FakeAdminBackend();
    queue = InMemorySyncQueue();
    quotations = FakeQuotationRepository();
    network = FakeNetwork();
    user = 'rep-1';
    processor = SyncQueueProcessor(
      queue: queue,
      quotations: quotations,
      gateway: ApiQuotationAdminGateway(backend),
      network: network,
      currentUserId: () => user,
    );
    quotations.byId['QT-1'] = quotation();
  });

  test('a queued quotation reaches Admin Review and links both sides',
      () async {
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');

    await processor.processAll();

    final item = queue.byQuotation['QT-1']!;
    expect(item.status, QuotationSyncStatus.accepted);
    expect(item.remoteStatus, 'PendingApproval');
    expect(item.remoteNumber, isNotNull);
    expect(item.remoteQuotationId, isNotNull);
    expect(quotations.byId['QT-1']!.remoteId, item.remoteQuotationId);
  });

  test('offline: nothing is attempted and no attempt is spent', () async {
    network.online = false;
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');

    await processor.processAll();

    final item = queue.byQuotation['QT-1']!;
    expect(item.status, QuotationSyncStatus.pendingSync);
    expect(item.attemptCount, 0);
    expect(backend.createCalls, 0);
  });

  test('signed out: nothing is pushed', () async {
    user = null;
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    await processor.processAll();
    expect(backend.createCalls, 0);
  });

  test("another rep's queued quotation is never pushed", () async {
    user = 'rep-2';
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    await processor.processAll();
    expect(backend.createCalls, 0);
    expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.pendingSync);
  });

  test('a transport failure backs off and keeps the backend link', () async {
    backend.failNext['submit'] = offline;
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');

    await processor.processAll();

    final item = queue.byQuotation['QT-1']!;
    expect(item.status, QuotationSyncStatus.pendingSync);
    expect(item.attemptCount, 1);
    expect(item.nextRetryAt, isNotNull);
    expect(item.remoteQuotationId, isNotNull,
        reason: 'persisted before the failure so the retry reuses it');
    expect(item.errorCode, 'Client.Network');
  });

  test('after the last backoff the item fails and waits for the rep', () async {
    backend.down = true;
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    for (var i = 0; i < kSyncRetryBackoffs.length + 1; i++) {
      final item = queue.byQuotation['QT-1']!;
      await queue.save(item.copyWith(nextRetryAt: () => null));
      await processor.processAll();
    }
    expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.failed);
  });

  test('a business rejection stops retrying and carries the code', () async {
    quotations.byId['QT-1'] = quotation(depotId: null);
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');

    await processor.processAll();

    final item = queue.byQuotation['QT-1']!;
    expect(item.status, QuotationSyncStatus.rejected);
    expect(item.errorCode, QuotationSyncErrorCodes.depotRequired);
  });

  test('price change becomes a conflict for the rep to review', () async {
    backend.failNext['submit'] = apiError(409, 'Quotation.PriceChanged');
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');

    await processor.processAll();

    final item = queue.byQuotation['QT-1']!;
    expect(item.status, QuotationSyncStatus.conflict);
    expect(item.errorCode, 'Quotation.PriceChanged');
  });

  test('retrying after a lost response does not create a second document',
      () async {
    backend.failNext['submit'] = offline;
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    await processor.processAll();
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    await processor.processAll();

    expect(backend.createCalls, 1);
    expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
  });

  group('refreshReviews — decisions come back from Admin', () {
    Future<String> submitted() async {
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await processor.processAll();
      return queue.byQuotation['QT-1']!.remoteQuotationId!;
    }

    test('returned: the rep sees it again, with the reason', () async {
      final id = await submitted();
      backend.docs[id]!
        ..status = 'Returned'
        ..decisionReason = 'Split delivery please';

      await processor.refreshReviews();

      final item = queue.byQuotation['QT-1']!;
      expect(item.status, QuotationSyncStatus.returned);
      expect(item.decisionReason, 'Split delivery please');
    });

    test('rejected by Admin is terminal for this quotation', () async {
      final id = await submitted();
      backend.docs[id]!.status = 'Rejected';

      await processor.refreshReviews();

      final item = queue.byQuotation['QT-1']!;
      expect(item.status, QuotationSyncStatus.rejected);
      expect(item.errorCode, 'Quotation.Rejected');
    });

    test('approved stays accepted and records the new status', () async {
      final id = await submitted();
      backend.docs[id]!.status = 'Approved';

      await processor.refreshReviews();

      final item = queue.byQuotation['QT-1']!;
      expect(item.status, QuotationSyncStatus.accepted);
      expect(item.remoteStatus, 'Approved');
    });

    test('a conflict resolved on the document screen becomes accepted',
        () async {
      backend.failNext['submit'] = apiError(409, 'Quotation.PriceChanged');
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await processor.processAll();
      final id = queue.byQuotation['QT-1']!.remoteQuotationId!;
      // The rep repriced and submitted online.
      backend.docs[id]!.status = 'PendingApproval';

      await processor.refreshReviews();

      expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
    });

    test('offline: the last known state is kept', () async {
      await submitted();
      backend.down = true;

      await processor.refreshReviews();

      expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
    });

    test('a returned quotation resubmitted goes to the same document',
        () async {
      final id = await submitted();
      backend.docs[id]!.status = 'Returned';
      await processor.refreshReviews();

      quotations.byId['QT-1'] =
          quotation(lines: [line('1500000017', 60)], remoteId: id);
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await processor.processAll();

      expect(backend.createCalls, 1);
      expect(backend.docs[id]!.status, 'PendingApproval');
      expect(backend.docs[id]!.lines.single.quantity, 60);
    });
  });
}
