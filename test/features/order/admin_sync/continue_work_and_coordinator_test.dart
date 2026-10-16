import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/features/order/data/services/api_quotation_admin_gateway.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/services/sync_queue_processor.dart';
import 'package:steelforce/features/order/domain/usecases/delete_quotation.dart';
import 'package:steelforce/features/order/domain/usecases/get_editable_remote_drafts.dart';
import 'package:steelforce/features/order/domain/usecases/watch_quotations.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/continue_work_cubit.dart';
import 'package:steelforce/features/order/presentation/services/quotation_sync_coordinator.dart';

import 'admin_sync_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdminBackend backend;
  late InMemorySyncQueue queue;
  late FakeQuotationRepository quotations;
  late FakeConnectivity connectivity;
  late SyncQueueProcessor processor;
  late QuotationSyncCoordinator coordinator;

  setUp(() {
    backend = FakeAdminBackend();
    queue = InMemorySyncQueue();
    quotations = FakeQuotationRepository()..byId['QT-1'] = quotation();
    connectivity = FakeConnectivity();
    processor = SyncQueueProcessor(
      queue: queue,
      quotations: quotations,
      gateway: ApiQuotationAdminGateway(backend),
      network: FakeNetwork(),
      currentUserId: () => 'rep-1',
    );
    coordinator = QuotationSyncCoordinator(
      processor: processor,
      queue: queue,
      connectivity: connectivity,
      coalesceDelay: const Duration(milliseconds: 10),
    );
  });

  tearDown(() => coordinator.stop());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  group('QuotationSyncCoordinator — sync is automatic', () {
    test('a newly queued quotation is sent without the rep tapping anything',
        () async {
      coordinator.start();
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await settle();
      expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
    });

    test('queued while offline, sent when real reachability returns', () async {
      connectivity.set(ConnectivityStatus.offline);
      coordinator.start();
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await settle();
      expect(backend.createCalls, 0);

      connectivity.set(ConnectivityStatus.online);
      await settle();
      expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.accepted);
    });

    test('after stop (sign-out) nothing more is sent', () async {
      coordinator.start();
      await coordinator.stop();
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await settle();
      expect(backend.createCalls, 0);
    });

    test('reconnect reads Admin decisions back', () async {
      coordinator.start();
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await settle();
      final id = queue.byQuotation['QT-1']!.remoteQuotationId!;
      backend.docs[id]!.status = 'Returned';

      connectivity.set(ConnectivityStatus.offline);
      connectivity.set(ConnectivityStatus.online);
      await settle();

      expect(queue.byQuotation['QT-1']!.status, QuotationSyncStatus.returned);
    });
  });

  group('ContinueWorkCubit — live, not static', () {
    ContinueWorkCubit build() => ContinueWorkCubit(
          watchQuotations: WatchQuotations(quotations),
          syncQueue: queue,
          deleteQuotation: DeleteQuotation(quotations),
          getRemoteDrafts:
              GetEditableRemoteDrafts(ApiQuotationAdminGateway(backend)),
          syncRunning: const Stream<bool>.empty(),
        );

    test('shows a local draft that was never queued', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await settle();
      expect(cubit.state.drafts.map((q) => q.id), ['QT-1']);
    });

    test('a quotation Admin returned comes back, with the reason', () async {
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      await processor.processAll();
      final id = queue.byQuotation['QT-1']!.remoteQuotationId!;
      backend.docs[id]!
        ..status = 'Returned'
        ..decisionReason = 'Wrong depot';
      await processor.refreshReviews();

      final cubit = build();
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.drafts.map((q) => q.id), ['QT-1']);
      expect(cubit.state.returnReasons['QT-1'], 'Wrong depot');
    });

    test('a queued (in-flight) quotation is not offered to continue', () async {
      await queue.enqueue('QT-1', ownerUserId: 'rep-1');
      final cubit = build();
      addTearDown(cubit.close);
      await settle();
      expect(cubit.state.drafts, isEmpty);
    });

    test('lists backend drafts with no local copy, skipping empty ones',
        () async {
      final withLines = await backend.createQuotation(depotId: 'depot-1');
      await backend.addLine(withLines.id,
          materialNumber: '1500000017', quantity: 1);
      await backend.createQuotation(depotId: 'depot-1'); // abandoned, empty

      final cubit = build();
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.remoteDrafts.map((r) => r.id), [withLines.id]);
      expect(cubit.state.totalCount, 2);
    });

    test('a backend draft already linked to a local quotation is not doubled',
        () async {
      final doc = await backend.createQuotation(depotId: 'depot-1');
      await backend.addLine(doc.id, materialNumber: '1500000017', quantity: 1);
      quotations.byId['QT-1'] = quotation(remoteId: doc.id);

      final cubit = build();
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.remoteDrafts, isEmpty);
      expect(cubit.state.totalCount, 1);
    });

    test('offline: the local drafts still show', () async {
      backend.down = true;
      final cubit = build();
      addTearDown(cubit.close);
      await settle();
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.drafts, hasLength(1));
    });
  });
}
