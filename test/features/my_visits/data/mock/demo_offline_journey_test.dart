import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// The demo's reachability, as `NetworkInfo` sees it in a demo build (the real
/// `ConnectivityService` is fed by `DemoReachabilityProbe`).
class _DemoNetworkInfo implements NetworkInfo {
  const _DemoNetworkInfo(this._network);
  final DemoNetwork _network;

  @override
  Future<bool> get isConnected async => _network.isOnline;
}

T _ok<T>(Result<T> result) => result.when(
      success: (value) => value,
      failure: (f) => fail('expected success, got $f'),
    );

/// The repositories the app registers, wired to the demo sources: a check-in
/// made with the demo offline is kept and queued, and drains through the demo
/// push once it is switched back online.
void main() {
  const logger = ConsoleAppLogger(verbose: false);
  const scope = RouteSyncScope(repId: DemoSeed.repId, territory: 'PP-NORTH');

  late AppDatabase db;
  late DemoNetwork network;
  late DemoVisitLedger ledger;
  late RouteDriftLocalDataSource routeLocal;
  late VisitDriftLocalDataSource visitLocal;
  late RouteSyncRepositoryImpl routeSync;
  late VisitRepositoryImpl visits;
  late VisitSyncRepositoryImpl visitSync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    network = DemoNetwork();
    ledger = DemoVisitLedger();
    final info = _DemoNetworkInfo(network);
    routeLocal = RouteDriftLocalDataSource(db.routeDao, logger);
    visitLocal = VisitDriftLocalDataSource(db.visitDao, logger);
    routeSync = RouteSyncRepositoryImpl(
      remote: DemoRouteRemoteDataSource(network, ledger),
      local: routeLocal,
      network: info,
      logger: logger,
    );
    visits = VisitRepositoryImpl(
      visitLocal,
      remote: DemoVisitCheckRemoteDataSource(network, ledger),
      network: info,
      logger: logger,
    );
    visitSync = VisitSyncRepositoryImpl(
      remote: DemoVisitSyncRemoteDataSource(network, ledger),
      local: visitLocal,
      network: info,
      logger: logger,
    );
  });

  tearDown(() => db.close());

  Future<RoutePlan> todayRoute() async => (await routeLocal.fetchAllRoutes())
      .singleWhere((r) => r.id == DemoSeed.todayRouteId);

  CheckInRecord checkInAt(String stopId, String id) => CheckInRecord(
        id: id,
        stopId: stopId,
        timestamp: DateTime.now(),
        latitude: DemoSeed.todayStops.first.latitude,
        longitude: DemoSeed.todayStops.first.longitude,
        accuracyMeters: 8,
        distanceFromDepotMeters: 0,
        isMocked: false,
        routeId: DemoSeed.todayRouteId,
      );

  test('route sync stores today\'s demo route', () async {
    _ok(await routeSync.runInitialSync(scope));

    final route = await todayRoute();
    expect(route.stops, hasLength(DemoSeed.todayStops.length));
    expect(route.stops.first.depot.name, DemoSeed.todayStops.first.name);
  });

  test('online, a check-in is sent straight away', () async {
    _ok(await routeSync.runInitialSync(scope));
    final stop = (await todayRoute()).stops.first;
    final record = checkInAt(stop.id, 'ci-online');

    _ok(await visits.checkIn(record));
    final sent = _ok(await visits.sendCheckIn(record));

    expect(sent.status, VisitSendStatus.sent);
    expect(sent.serverVisit?.status, VisitStatus.checkedIn);
    expect(await visitLocal.fetchPendingCheckIns(), isEmpty);
  });

  test('offline, a check-in queues locally and drains when back online',
      () async {
    _ok(await routeSync.runInitialSync(scope));
    final stop = (await todayRoute()).stops[1];
    final record = checkInAt(stop.id, 'ci-offline');

    network.setOnline(false);
    _ok(await visits.checkIn(record));
    final queued = _ok(await visits.sendCheckIn(record));
    expect(queued.status, VisitSendStatus.queued);
    expect((await visitLocal.fetchPendingCheckIns()).map((r) => r.id),
        ['ci-offline']);
    expect(ledger.hasVisit(stop.id), isFalse);

    // Still offline: the drain refuses rather than losing the row.
    expect(await visitSync.pushPendingVisitData(), isA<Failed<Object?>>());
    expect(await visitLocal.fetchPendingCheckIns(), hasLength(1));

    network.setOnline(true);
    _ok(await visitSync.pushPendingVisitData());

    expect(await visitLocal.fetchPendingCheckIns(), isEmpty);
    expect(ledger.execution(stop.id)?.status, 'checkedIn');

    // The next pull carries the server's view of the stop.
    _ok(await routeSync.runDeltaSync(scope));
    final after = (await todayRoute()).stops[1];
    expect(after.status, VisitStatus.checkedIn);
    expect((await todayRoute()).status, RouteStatus.inProgress);
  });

  test('offline, route sync fails as a network failure and keeps the day',
      () async {
    _ok(await routeSync.runInitialSync(scope));
    network.setOnline(false);

    expect(await routeSync.runDeltaSync(scope), isA<Failed<Object?>>());
    expect((await todayRoute()).stops, hasLength(DemoSeed.todayStops.length));
  });
}
