import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/data/services/api_quotation_admin_gateway.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/services/sync_queue_processor.dart';
import 'package:steelforce/features/order/presentation/services/quotation_sync_coordinator.dart';

import 'admin_sync_fakes.dart';

/// A quotation taken at a stop must reach the server after that stop's
/// check-in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySyncQueue queue;
  late SyncQueueProcessor processor;

  setUp(() {
    queue = InMemorySyncQueue();
    final quotations = FakeQuotationRepository()..byId['QT-1'] = quotation();
    processor = SyncQueueProcessor(
      queue: queue,
      quotations: quotations,
      gateway: ApiQuotationAdminGateway(FakeAdminBackend()),
      network: FakeNetwork(),
      currentUserId: () => 'rep-1',
    );
  });

  QuotationSyncCoordinator build(Future<void> Function() sendFirst) =>
      QuotationSyncCoordinator(
        processor: processor,
        queue: queue,
        connectivity: FakeConnectivity(),
        sendFirst: sendFirst,
        coalesceDelay: const Duration(milliseconds: 10),
      );

  test('check-ins are sent before any quotation', () async {
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    QuotationSyncStatus? whenCheckInsWent;
    final coordinator = build(() async {
      whenCheckInsWent = queue.byQuotation['QT-1']!.status;
    });

    await coordinator.runNow(reviews: false);

    expect(whenCheckInsWent, QuotationSyncStatus.pendingSync);
    expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
  });

  test('a check-in failure never holds a quotation back', () async {
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    final coordinator = build(() async => throw StateError('visits down'));

    await coordinator.runNow(reviews: false);

    expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
  });

  test('runNow waits for a run already in progress, then sends', () async {
    final gate = Completer<void>();
    var firstCalls = 0;
    final coordinator = build(() async {
      firstCalls++;
      if (firstCalls == 1) await gate.future;
    });

    final inProgress = coordinator.runNow(reviews: false);
    await queue.enqueue('QT-1', ownerUserId: 'rep-1');
    var released = false;
    final second =
        coordinator.runNow(reviews: false).then((_) => released = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(released, isFalse, reason: 'still waiting on the first run');

    gate.complete();
    await inProgress;
    await second;

    expect(firstCalls, 2);
    expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
  });
}
