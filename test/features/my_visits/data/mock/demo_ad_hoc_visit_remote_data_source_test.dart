import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

Matcher _apiError(String code) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

void main() {
  final clock = DateTime.utc(2026, 10, 14, 4);
  final offPlan = DemoSeed.depots[9];

  late DemoNetwork network;
  late DemoVisitLedger ledger;
  late DemoAdHocVisitRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    ledger = DemoVisitLedger(clock: () => clock);
    source = DemoAdHocVisitRemoteDataSource(network, ledger);
  });

  test('adds an off-plan depot to today\'s route', () async {
    final response =
        await source.create(sk: offPlan.code, clientRequestId: 'req-1');

    expect(response.created, isTrue);
    expect(response.visitDate, DateTime(2026, 10, 14));
    expect(response.depot.id, offPlan.id);
    expect(response.depot.code, offPlan.code);
    expect(response.stop.routeId, DemoSeed.todayRouteId);
    expect(response.stop.id, startsWith(kDemoStopIdPrefix));
    expect(response.stop.visitSource, VisitSource.adHoc);
    expect(response.stop.status, VisitStatus.pending);
    expect(response.stop.plannedArrival, isNull);
    expect(response.stop.sequence, 1001);
    expect(ledger.adHocStopsOn('2026-10-14'), hasLength(1));
  });

  test('a replay of the same request answers created: false, same stop',
      () async {
    final first =
        await source.create(sk: offPlan.code, clientRequestId: 'req-1');
    final replay =
        await source.create(sk: offPlan.code, clientRequestId: 'req-1');

    expect(replay.created, isFalse);
    expect(replay.stop.id, first.stop.id);
    expect(ledger.adHocStopsOn('2026-10-14'), hasLength(1));
  });

  test('a depot already on today\'s Call Plan is 409 already planned',
      () async {
    await expectLater(
      source.create(
          sk: DemoSeed.todayStops.first.code, clientRequestId: 'req-1'),
      _apiError(ApiErrorCodes.visitDepotAlreadyPlanned),
    );
  });

  test('the same depot added twice today is 409 already exists', () async {
    await source.create(sk: offPlan.code, clientRequestId: 'req-1');
    await expectLater(
      source.create(sk: offPlan.code, clientRequestId: 'req-2'),
      _apiError(ApiErrorCodes.visitAdHocAlreadyExists),
    );
  });

  test('an unknown SAP code is 404 depot not found', () async {
    await expectLater(
      source.create(sk: '9999999999', clientRequestId: 'req-1'),
      _apiError(ApiErrorCodes.visitDepotNotFound),
    );
  });

  test('a second ad hoc stop is numbered after the first', () async {
    await source.create(sk: offPlan.code, clientRequestId: 'req-1');
    final second = await source.create(
        sk: DemoSeed.depots[10].code, clientRequestId: 'req-2');
    expect(second.stop.sequence, 1002);
  });

  test('offline, the request fails as a network error and adds nothing',
      () async {
    network.setOnline(false);
    await expectLater(
      source.create(sk: offPlan.code, clientRequestId: 'req-1'),
      _apiError(ApiErrorCodes.network),
    );
    expect(ledger.adHocFor('req-1'), isNull);
  });
}
