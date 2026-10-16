import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/data/services/api_quotation_admin_gateway.dart';
import 'package:steelforce/features/order/domain/entities/admin_submit_result.dart';

import 'admin_sync_fakes.dart';

void main() {
  late FakeAdminBackend backend;
  late ApiQuotationAdminGateway gateway;
  late List<String> created;

  Future<void> onCreated(String id) async => created.add(id);

  setUp(() {
    backend = FakeAdminBackend();
    gateway = ApiQuotationAdminGateway(backend);
    created = [];
  });

  group('submit — happy path', () {
    test('opens a document, sends lines and discounts, submits for review',
        () async {
      final q = quotation(lines: [
        line('1500000017', 100, discount: 2.5),
        line('1500000018', 40),
      ]);

      final result =
          await gateway.submit(q, remoteId: null, onRemoteCreated: onCreated);

      expect(result, isA<AdminSubmitted>());
      final ok = result as AdminSubmitted;
      expect(ok.remoteStatus, 'PendingApproval');
      expect(created, [ok.remoteId]);
      final doc = backend.docs[ok.remoteId]!;
      expect(doc.lines.map((l) => l.material), ['1500000017', '1500000018']);
      expect(doc.lines.first.manualPercent, 2.5);
      expect(backend.createCalls, 1);
      expect(backend.submitCalls, 1);
    });

    test('reports the new id before sending any line', () async {
      backend.failNext['addLine'] = offline;
      final result = await gateway.submit(quotation(),
          remoteId: null, onRemoteCreated: onCreated);

      expect(result, isA<AdminTransportFailure>());
      expect(created, hasLength(1),
          reason: 'a retry must be able to find this document');
    });

    test('merges two cart rows of one material into one backend line',
        () async {
      final result = await gateway.submit(
        quotation(lines: [line('1500000017', 10), line('1500000017', 5)]),
        remoteId: null,
        onRemoteCreated: onCreated,
      );
      final doc = backend.docs[(result as AdminSubmitted).remoteId]!;
      expect(doc.lines, hasLength(1));
      expect(doc.lines.single.quantity, 15);
    });
  });

  group('submit — retries converge instead of duplicating', () {
    test('a retry on the linked document reuses it and adds no duplicate',
        () async {
      backend.failNext['submit'] = offline;
      final first = await gateway.submit(quotation(),
          remoteId: null, onRemoteCreated: onCreated);
      expect(first, isA<AdminTransportFailure>());

      final second = await gateway.submit(quotation(),
          remoteId: created.single, onRemoteCreated: onCreated);

      expect(second, isA<AdminSubmitted>());
      expect(backend.createCalls, 1);
      expect(backend.docs[created.single]!.lines, hasLength(1));
    });

    test('a lost submit response is treated as done, not resubmitted',
        () async {
      final first = await gateway.submit(quotation(),
          remoteId: null, onRemoteCreated: onCreated);
      final id = (first as AdminSubmitted).remoteId;

      final again = await gateway.submit(quotation(),
          remoteId: id, onRemoteCreated: onCreated);

      expect(again, isA<AdminSubmitted>());
      expect(backend.submitCalls, 1);
    });

    test('reconciles an existing draft: changes quantity, removes extras',
        () async {
      final seeded = await backend.createQuotation(depotId: 'depot-1');
      await backend.addLine(seeded.id,
          materialNumber: '1500000017', quantity: 1);
      await backend.addLine(seeded.id,
          materialNumber: '9999999999', quantity: 7);

      final result = await gateway.submit(
        quotation(lines: [line('1500000017', 250)]),
        remoteId: seeded.id,
        onRemoteCreated: onCreated,
      );

      expect(result, isA<AdminSubmitted>());
      final doc = backend.docs[seeded.id]!;
      expect(doc.lines.map((l) => l.material), ['1500000017']);
      expect(doc.lines.single.quantity, 250);
      expect(created, isEmpty);
    });

    test('a linked document the backend no longer has is replaced', () async {
      final result = await gateway.submit(quotation(),
          remoteId: 'srv-gone', onRemoteCreated: onCreated);
      expect(result, isA<AdminSubmitted>());
      expect(created, hasLength(1));
    });

    test('does not resend unchanged discounts', () async {
      final q = quotation(lines: [line('1500000017', 10, discount: 3)]);
      backend.failNext['submit'] = offline;
      await gateway.submit(q, remoteId: null, onRemoteCreated: onCreated);
      expect(backend.setDiscountCalls, 1);

      await gateway.submit(q,
          remoteId: created.single, onRemoteCreated: onCreated);
      expect(backend.setDiscountCalls, 1);
    });
  });

  group('submit — failures are classified for the retry policy', () {
    test('offline is a transport failure', () async {
      backend.down = true;
      final r = await gateway.submit(quotation(),
          remoteId: null, onRemoteCreated: onCreated);
      expect(r, isA<AdminTransportFailure>());
    });

    test('502 PriceUnavailable is retryable, never a rejection', () async {
      backend.failNext['addLine'] = apiError(502, 'Quotation.PriceUnavailable');
      final r = await gateway.submit(quotation(),
          remoteId: null, onRemoteCreated: onCreated);
      expect(r, isA<AdminTransportFailure>());
      expect(
          (r as AdminTransportFailure).errorCode, 'Quotation.PriceUnavailable');
    });

    test('422 MaterialNotPriced is a rejection the rep must act on', () async {
      backend.failNext['addLine'] =
          apiError(422, 'Quotation.MaterialNotPriced');
      final r = await gateway.submit(quotation(),
          remoteId: null, onRemoteCreated: onCreated);
      expect(r, isA<AdminRejected>());
      expect((r as AdminRejected).errorCode, 'Quotation.MaterialNotPriced');
      expect(r.remoteId, created.single);
    });

    test('409 PriceChanged needs the rep to review — it is not auto-accepted',
        () async {
      backend.failNext['submit'] = apiError(409, 'Quotation.PriceChanged');
      final r = await gateway.submit(quotation(),
          remoteId: null, onRemoteCreated: onCreated);
      expect(r, isA<AdminNeedsReview>());
      expect((r as AdminNeedsReview).remoteId, created.single);
    });

    test('an unknown depot is rejected with the backend code', () async {
      final r = await gateway.submit(quotation(depotId: 'depot-unsynced'),
          remoteId: null, onRemoteCreated: onCreated);
      expect(r, isA<AdminRejected>());
      expect((r as AdminRejected).errorCode, 'Quotation.NotFound');
    });
  });

  group('submit — refused on the device before any call', () {
    test('a lead quotation with no depot', () async {
      final r = await gateway.submit(quotation(depotId: null),
          remoteId: null, onRemoteCreated: onCreated);
      expect((r as AdminRejected).errorCode,
          QuotationSyncErrorCodes.depotRequired);
      expect(backend.createCalls, 0);
    });

    test('a customized line the contract cannot carry', () async {
      final r = await gateway.submit(
          quotation(lines: [line('1500000017', 1, customized: true)]),
          remoteId: null,
          onRemoteCreated: onCreated);
      expect((r as AdminRejected).errorCode,
          QuotationSyncErrorCodes.customizationUnsupported);
      expect(backend.createCalls, 0);
    });

    test('a line with no material number', () async {
      final r = await gateway.submit(quotation(lines: [line('', 1)]),
          remoteId: null, onRemoteCreated: onCreated);
      expect((r as AdminRejected).errorCode,
          QuotationSyncErrorCodes.materialMissing);
    });
  });

  group('fetchReviews', () {
    test('one list call answers every document still in review', () async {
      final a = await backend.createQuotation(depotId: 'depot-1');
      final b = await backend.createQuotation(depotId: 'depot-1');
      backend.docs[a.id]!.status = 'PendingApproval';
      backend.docs[b.id]!.status = 'Approved';

      final reviews = await gateway.fetchReviews([a.id, b.id]);

      expect(reviews.map((r) => r.status), ['PendingApproval', 'Approved']);
      expect(backend.listCalls, 1);
      expect(backend.detailCalls, 0);
    });

    test('a returned document is read in full for its reason', () async {
      final a = await backend.createQuotation(depotId: 'depot-1');
      backend.docs[a.id]!
        ..status = 'Returned'
        ..decisionReason = 'Discount too high';

      final reviews = await gateway.fetchReviews([a.id]);

      expect(reviews.single.status, 'Returned');
      expect(reviews.single.decisionReason, 'Discount too high');
    });

    test('a document the backend no longer has reads as gone', () async {
      final reviews = await gateway.fetchReviews(['srv-missing']);
      expect(reviews.single.isGone, isTrue);
    });
  });
}
