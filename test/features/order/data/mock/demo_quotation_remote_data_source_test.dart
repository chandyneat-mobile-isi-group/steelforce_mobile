import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_remote_data_source.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_store.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

Matcher _apiError(String code, [int? status]) => throwsA(isA<ApiException>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.statusCode, 'statusCode', status));

void main() {
  late DemoNetwork network;
  late DemoQuotationRemoteDataSource source;

  // Depot 0 holds a 1.5% Palm Profile and a 2% Cold Formed agreement.
  final depot = DemoSeed.depots.first;
  const palm = '2400001018'; // TILE 1000 GL, 4.12 / M
  const purlin = '1400000891'; // C Purlin 150x65, 53.22 / PCS

  setUp(() {
    network = DemoNetwork();
    source = DemoQuotationRemoteDataSource(
        network, DemoQuotationStore(DemoMaterialBook()));
  });

  group('seeded quotation book', () {
    test('holds 16 documents across every tab group, newest first', () async {
      final all = await source.fetchQuotations(pageSize: 100);
      expect(all.quotations, hasLength(16));
      expect(all.metadata!.totalRecords, 16);
      expect(
        all.quotations.map((q) => q.statusGroup).toSet(),
        QuotationStatusGroup.values.toSet(),
      );
      final updated = all.quotations.map((q) => q.updatedAt!).toList();
      for (var i = 1; i < updated.length; i++) {
        expect(updated[i].isAfter(updated[i - 1]), isFalse);
      }
      for (final q in all.quotations) {
        expect(DemoSeed.depotById(q.depotId), isNotNull, reason: q.number);
        expect(q.depotName, DemoSeed.depotById(q.depotId)!.name);
      }
    });

    test(
        'filters by tab group, concrete status and depot; unknown matches '
        'nothing', () async {
      Future<int> count(String? status, [String? depotId]) async =>
          (await source.fetchQuotations(
                  status: status, depotId: depotId, pageSize: 100))
              .quotations
              .length;

      expect(await count('Drafts'), 3);
      expect(await count('Waiting'), 5);
      expect(await count('pendingapproval'), 3);
      expect(await count('Closed'), 4);
      expect(await count('NoSuchStatus'), 0);
      expect(await count(null, depot.id), 2);
      expect(await count(null, depot.code), 2);
    });

    test('pages with the server metadata', () async {
      final first = await source.fetchQuotations(page: 1, pageSize: 5);
      expect(first.quotations, hasLength(5));
      expect(first.metadata!.hasNextPage, isTrue);
      expect(first.metadata!.totalPages, 4);
      final last = await source.fetchQuotations(page: 4, pageSize: 5);
      expect(last.quotations, hasLength(1));
      expect(last.metadata!.hasNextPage, isFalse);
    });

    test('every seeded total is derived from its lines', () async {
      final all = await source.fetchQuotations(pageSize: 100);
      for (final summary in all.quotations) {
        final doc = await source.fetchQuotationById(summary.id);
        var gross = 0.0, discount = 0.0;
        for (final line in doc.lines) {
          expect(line.gross, closeTo(line.quantity * line.priceAmount, 0.001));
          expect(line.net, closeTo(line.gross - line.discountTotal, 0.001));
          gross += line.gross;
          discount += line.discountTotal;
        }
        expect(doc.totals.gross, closeTo(gross, 0.001), reason: doc.number);
        expect(doc.totals.discountTotal, closeTo(discount, 0.001));
        expect(doc.totals.net, closeTo(gross - discount, 0.001));
        expect(doc.totals.tax, isNull);
        expect(summary.net, doc.totals.net);
        // Lines are priced from the demo catalog, so the finder agrees.
        for (final line in doc.lines) {
          expect(line.priceAmount,
              DemoMaterialBook.isi(line.materialNumber).price);
        }
      }
    });

    test('a returned quotation carries its reason, revision and trail',
        () async {
      final drafts = await source.fetchQuotations(status: 'Returned');
      final doc = await source.fetchQuotationById(drafts.quotations.single.id);
      expect(doc.isEditable, isTrue);
      expect(doc.revision, 2);
      expect(doc.decisionReason, isNotEmpty);
      final history = await source.fetchHistory(doc.id);
      expect(
          history.map((h) => h.action), ['Created', 'Submitted', 'Returned']);
      expect(history.last.comment, doc.decisionReason);
    });
  });

  group('create → lines → discounts → submit', () {
    test('computes totals and moves to Admin Review', () async {
      var doc = await source.createQuotation(depotId: depot.id);
      expect(doc.status, 'Draft');
      expect(doc.depotName, depot.name);
      expect(doc.number, matches(RegExp(r'^Q-\d{4}-0420$')));

      doc = await source.addLine(doc.id, materialNumber: palm, quantity: 100);
      doc = await source.addLine(doc.id,
          materialNumber: purlin, quantity: 10, unit: 'PCS');
      final palmLine = doc.lines.firstWhere((l) => l.materialNumber == palm);
      doc = await source.setDiscounts(doc.id, lines: [
        QuotationDiscountIntent(lineId: palmLine.id, percent: 2),
      ]);

      // Palm: 412.000 gross; agreement 1.5% 6.180, pickup 1% 4.120,
      // manual 2% 8.240 → 18.540 off, 393.460 net.
      final p = doc.lines.firstWhere((l) => l.materialNumber == palm);
      expect(p.gross, 412.0);
      expect(p.discountTotal, closeTo(18.54, 1e-9));
      expect(p.manualDiscount!.percent, 2);
      expect(p.agreementDiscounts.single.percent, 1.5);
      // Purlin: 532.200 gross; agreement 2% 10.644, pickup 1% 5.322.
      final c = doc.lines.firstWhere((l) => l.materialNumber == purlin);
      expect(c.gross, closeTo(532.2, 1e-9));
      expect(c.discountTotal, closeTo(15.966, 1e-9));

      expect(doc.totals.gross, closeTo(944.2, 1e-9));
      expect(doc.totals.discountTotal, closeTo(34.506, 1e-9));
      expect(doc.totals.net, closeTo(909.694, 1e-9));
      expect(doc.totals.isEstimate, isTrue);

      final preview = await source.getPreview(doc.id);
      expect(preview.totals.net, doc.totals.net);
      expect(preview.requiredApprovalLevel, 1);

      final submitted = await source.submit(doc.id);
      expect(submitted.status, 'PendingApproval');
      expect(submitted.statusGroup, QuotationStatusGroup.waiting);
      expect(submitted.submittedAt, isNotNull);
      expect(submitted.totals.net, closeTo(909.694, 1e-9));

      final waiting = await source.fetchQuotations(status: 'Waiting');
      expect(waiting.quotations.map((q) => q.id), contains(doc.id));
    });

    test('history accumulates per action', () async {
      final doc = await source.createQuotation(depotId: depot.id);
      await source.addLine(doc.id, materialNumber: palm, quantity: 50);
      await source.reprice(doc.id);
      await source.cancel(doc.id);

      final history = await source.fetchHistory(doc.id);
      expect(
          history.map((h) => h.action), ['Created', 'Repriced', 'Cancelled']);
      expect(history.every((h) => h.actorName == DemoSeed.repName), isTrue);
      final closed = await source.fetchQuotationById(doc.id);
      expect(closed.statusGroup, QuotationStatusGroup.closed);
    });

    test('create with a clientId is idempotent', () async {
      final a = await source.createQuotation(depotId: depot.id, clientId: 'c1');
      final b = await source.createQuotation(depotId: depot.id, clientId: 'c1');
      expect(b.id, a.id);
      expect(b.number, a.number);
    });
  });

  group('refuses as the live contract does', () {
    test('unknown document → 404', () {
      expect(source.fetchQuotationById('nope'),
          _apiError('Quotation.NotFound', 404));
    });

    test('duplicate, unpriced and wrong-unit lines → 422', () async {
      final doc = await source.createQuotation(depotId: depot.id);
      await source.addLine(doc.id, materialNumber: palm, quantity: 1);
      expect(source.addLine(doc.id, materialNumber: palm, quantity: 1),
          _apiError('Quotation.DuplicateLine', 422));
      expect(source.addLine(doc.id, materialNumber: '9999999999', quantity: 1),
          _apiError('Quotation.MaterialNotPriced', 422));
      expect(
          source.addLine(doc.id,
              materialNumber: purlin, quantity: 1, unit: 'KG'),
          _apiError('Quotation.UnitMismatch', 422));
      expect(source.addLine(doc.id, materialNumber: purlin, quantity: 0),
          _apiError('Quotation.QuantityInvalid', 422));
    });

    test('a line discounted past the cap → 422, not trimmed', () async {
      final doc = await source.createQuotation(depotId: depot.id);
      final withLine =
          await source.addLine(doc.id, materialNumber: palm, quantity: 10);
      // 1.5% agreement + 1% pickup + 5% manual = 7.5% > 7%.
      expect(
          source.setDiscounts(doc.id, lines: [
            QuotationDiscountIntent(
                lineId: withLine.lines.single.id, percent: 5)
          ]),
          _apiError('Quotation.DiscountCapExceeded', 422));
    });

    test('submit needs lines and a delivery address; then is read-only',
        () async {
      final empty = await source.createQuotation(depotId: depot.id);
      expect(source.submit(empty.id), _apiError('Quotation.NoLines', 422));

      final delivery = await source.createQuotation(
          depotId: depot.id, shipmentType: 'Delivery');
      await source.addLine(delivery.id, materialNumber: palm, quantity: 1);
      expect(source.submit(delivery.id),
          _apiError('Quotation.ShipToRequired', 422));

      final ok = await source.createQuotation(depotId: depot.id);
      await source.addLine(ok.id, materialNumber: palm, quantity: 1);
      await source.submit(ok.id);
      expect(source.addLine(ok.id, materialNumber: purlin, quantity: 1),
          _apiError('Quotation.NotEditable', 409));
    });
  });

  group('offline', () {
    test('every call fails as a network error and changes nothing', () async {
      final before = await source.fetchQuotations(pageSize: 100);
      network.setOnline(false);
      final offline = _apiError(ApiErrorCodes.network);

      expect(source.fetchQuotations(), offline);
      expect(source.createQuotation(depotId: depot.id), offline);
      expect(source.fetchQuotationById(before.quotations.first.id), offline);
      expect(source.getPreview(before.quotations.first.id), offline);
      expect(source.fetchHistory(before.quotations.first.id), offline);
      expect(source.fetchDepotAgreements(depot.id), offline);
      expect(source.fetchDepotIncentives(depot.id), offline);
      expect(source.fetchDepotPromotions(depot.id), offline);
      expect(source.fetchDiscountAuthority(), offline);

      await Future<void>.delayed(Duration.zero);
      network.setOnline(true);
      final after = await source.fetchQuotations(pageSize: 100);
      expect(after.quotations, hasLength(before.quotations.length));
    });
  });

  group('depot commercial reads', () {
    test('agreements, incentives, promotions and authority parse', () async {
      final agreements = await source.fetchDepotAgreements(depot.id);
      expect(agreements.map((a) => a.percent), [1.5, 2.0]);
      final groups = await source.fetchDepotIncentives(depot.id);
      expect(groups.map((g) => g.titleKey), [
        'promotions.group.depot_discount',
        'promotions.group.cod_pickup',
        'promotions.group.depot_requests',
        'promotions.group.free_goods',
      ]);
      final promos = await source.fetchDepotPromotions(depot.id);
      expect(promos.length, groups.expand((g) => g.promos).length);
      final authority = await source.fetchDiscountAuthority();
      expect(authority.maxManualDiscountPercent, 3);
      expect(authority.lineDiscountCapPercent, 7);
    });
  });
}
