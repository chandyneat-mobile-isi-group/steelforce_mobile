import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_route_fixtures.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

void main() {
  const scope = RouteSyncScope(repId: 'demo-rep-0001', territory: 'PP-NORTH');
  final clock = DateTime.utc(2026, 10, 14, 4, 30);

  late DemoNetwork network;
  late DemoVisitLedger ledger;
  late DemoRouteRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    ledger = DemoVisitLedger(clock: () => clock);
    source = DemoRouteRemoteDataSource(network, ledger);
  });

  RoutePlan today(List<RoutePlan> routes) =>
      routes.singleWhere((r) => r.id == DemoSeed.todayRouteId);

  test('initial pull parses today\'s route on the shared demo depots',
      () async {
    final page = await source.fetchInitial(scope: scope, page: 0, pageSize: 50);

    expect(page.hasMore, isFalse);
    expect(page.routes, hasLength(5));
    expect(page.generatedAt, clock);
    expect(page.territories, ['PP-NORTH']);

    final route = today(page.routes);
    expect(route.visitDate, DateTime.utc(2026, 10, 14));
    expect(route.status, RouteStatus.published);
    expect(route.repId, DemoSeed.repId);
    expect([for (final s in route.stops) s.depot.id],
        [for (final d in DemoSeed.todayStops) d.id]);
    expect(route.stops.every((s) => s.status == VisitStatus.pending), isTrue);

    final first = route.stops.first.depot;
    expect(first.code, DemoSeed.todayStops.first.code);
    expect(first.nameKh, DemoSeed.todayStops.first.nameKm);
    expect(first.hasCoordinates, isTrue);
  });

  test('every stop resolves to a depot carried on the same page', () async {
    final page = await source.fetchInitial(scope: scope, page: 0, pageSize: 50);
    final depotIds = {for (final d in page.depots) d.id};
    for (final route in page.routes) {
      for (final stop in route.stops) {
        expect(depotIds, contains(stop.depot.id));
      }
    }
    final stopIds = [
      for (final r in page.routes)
        for (final s in r.stops) s.id
    ];
    expect(stopIds.toSet(), hasLength(stopIds.length),
        reason: 'stop ids must be unique across days');
  });

  test('past days are worked, future days are not', () async {
    final page = await source.fetchInitial(scope: scope, page: 0, pageSize: 50);
    final day = DemoRouteFixtures.utcDay(clock);
    final past = page.routes.where((r) => r.visitDate.isBefore(day));
    final future = page.routes.where((r) => r.visitDate.isAfter(day));

    expect(past, hasLength(2));

    expect(past.every((r) => r.status == RouteStatus.completed), isTrue);
    expect(past.expand((r) => r.stops).map((s) => s.status),
        containsAll([VisitStatus.checkedOut, VisitStatus.missed]));
    expect(future, hasLength(2));
    expect(
        future.expand((r) => r.stops).every((s) => s.status.name == 'pending'),
        isTrue);
  });

  test('pages through the set 0-based', () async {
    final first = await source.fetchInitial(scope: scope, page: 0, pageSize: 2);
    final second =
        await source.fetchInitial(scope: scope, page: 1, pageSize: 2);
    final last = await source.fetchInitial(scope: scope, page: 2, pageSize: 2);

    expect(first.hasMore, isTrue);
    expect(second.hasMore, isTrue);
    expect(last.hasMore, isFalse);
    expect([...first.routes, ...second.routes, ...last.routes].map((r) => r.id),
        hasLength(5));
  });

  test('unscoped profile falls back to the demo territory', () async {
    final page = await source.fetchDelta(
      scope:
          const RouteSyncScope(repId: 'r', territory: RouteSyncScope.unscoped),
      since: clock,
    );
    expect(page.territories, ['PP-CENTRAL']);
  });

  test('a delta reflects check-ins and check-outs the server has seen',
      () async {
    final initial =
        await source.fetchInitial(scope: scope, page: 0, pageSize: 50);
    final stops = today(initial.routes).stops;

    ledger.checkIn(
        id: 'ci-1', stopId: stops[0].id, timestamp: clock, strict: false);
    ledger.checkOut(
        id: 'co-1',
        stopId: stops[0].id,
        timestamp: clock.add(const Duration(minutes: 30)),
        durationMinutes: 30);
    ledger.checkIn(id: 'ci-2', stopId: stops[1].id, timestamp: clock);

    final delta = await source.fetchDelta(scope: scope, since: clock);
    final route = today(delta.routes);

    expect(route.status, RouteStatus.inProgress);
    expect(route.stops[0].status, VisitStatus.checkedOut);
    expect(route.stops[0].actualArrival, clock);
    expect(route.stops[1].status, VisitStatus.checkedIn);
    expect(route.stops[2].status, VisitStatus.pending);
  });

  test('an ad hoc visit joins today\'s route on the next pull', () async {
    final extra = DemoSeed.depots[8];
    await DemoAdHocVisitRemoteDataSource(network, ledger)
        .create(sk: extra.code, clientRequestId: 'req-1');

    final delta = await source.fetchDelta(scope: scope, since: clock);
    final added = today(delta.routes).stops.last;

    expect(added.depot.id, extra.id);
    expect(added.visitSource, VisitSource.adHoc);
    expect(added.plannedArrival, isNull);
  });

  test('offline, both pulls fail as a network error', () async {
    network.setOnline(false);
    final isNetwork = throwsA(isA<ApiException>()
        .having((e) => e.code, 'code', ApiErrorCodes.network));

    await expectLater(
        source.fetchInitial(scope: scope, page: 0, pageSize: 50), isNetwork);
    await expectLater(source.fetchDelta(scope: scope, since: clock), isNetwork);
  });

  test('today follows the clock', () {
    final tomorrow =
        DemoVisitLedger(clock: () => clock.add(const Duration(days: 1)));
    final routes = DemoRouteFixtures(tomorrow).routes(territory: 'PP-NORTH');
    final todayJson =
        routes.singleWhere((r) => r['id'] == DemoSeed.todayRouteId);
    expect(
        todayJson['visitDate'], DateTime.utc(2026, 10, 15).toIso8601String());
  });
}
