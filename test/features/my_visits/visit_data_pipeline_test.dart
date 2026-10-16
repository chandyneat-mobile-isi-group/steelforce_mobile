import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/local/depot_drift_local_data_source.dart';
import 'package:steelforce/features/depots/data/remote/api_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';

import 'route_feed_fixture.dart';

/// The whole Visit data pipeline, in the order the app runs it:
///
///   depot sync → route sync → today's routes → stops
///
/// Each stage is a hard precondition for the next (`route_stops.depot_id`
/// is a live FK), so a break anywhere shows up identically at the UI — an
/// empty dashboard. Testing the stages in isolation cannot tell them apart,
/// which is why this walks the chain end to end.
class _AlwaysOnline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  late AppDatabase db;
  late DepotDriftLocalDataSource depotLocal;
  late RouteDriftLocalDataSource routeLocal;
  late DepotSyncRepositoryImpl depotSync;
  late RouteSyncRepositoryImpl routeSync;
  late RouteRepositoryImpl routes;

  const logger = ConsoleAppLogger(verbose: false);
  const scope = RouteSyncScope(repId: 'rep-1', territory: 'Phnom Penh');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    depotLocal = DepotDriftLocalDataSource(db.depotDao);
    routeLocal = RouteDriftLocalDataSource(db.routeDao, logger);
    depotSync = DepotSyncRepositoryImpl(
      remote: ApiDepotRemoteDataSource(scriptedDepotFeed()),
      local: depotLocal,
      network: _AlwaysOnline(),
      logger: logger,
    );
    // The feed reads the directory at request time rather than at
    // construction: stage 1 has not run yet here, so the depot ids do not
    // exist when this is wired up.
    routeSync = RouteSyncRepositoryImpl(
      remote: ApiRouteRemoteDataSource(
        scriptedRouteFeed(
          depotIds: () async => (await depotLocal.browse(page: 0, pageSize: 12))
              .map((c) => c.id)
              .toList(),
        ),
      ),
      local: routeLocal,
      network: _AlwaysOnline(),
    );
    routes = RouteRepositoryImpl(routeLocal);
  });
  tearDown(() => db.close());

  test('stage 1: depot sync populates the directory', () async {
    final result = await depotSync.runInitialSync();
    final upserted = result.when(success: (r) => r.upserted, failure: (_) => 0);

    expect(upserted, greaterThan(0),
        reason: 'routes cannot be pulled without a depot directory');

    final page = await depotLocal.browse(page: 0, pageSize: 5);
    expect(page, isNotEmpty);
  });

  test('stage 2+3: routes and their stops reach the dashboard', () async {
    await depotSync.runInitialSync();
    await routeSync.runInitialSync(scope);

    final today = (await routes.fetchTodayRoutes())
        .when(success: (r) => r, failure: (_) => const []);

    expect(today, isNotEmpty, reason: 'Route Dashboard would be empty');

    final withStops = today.where((r) => r.stops.isNotEmpty).toList();
    expect(withStops, isNotEmpty,
        reason: 'Stop Dashboard would be empty: routes synced but every one '
            'of them lost its stops');

    // Each stop must carry the depot the rep is going to visit — a stop
    // with no shop name renders as a blank row.
    for (final stop in withStops.first.stops) {
      expect(stop.depot.name.trim(), isNotEmpty);
    }
  });

  test('the full chain is reproducible on a second run', () async {
    // Re-entering My Visits re-runs sync. Upserts must be idempotent, or the
    // second open either duplicates stops or trips the FK and shows nothing.
    await depotSync.runInitialSync();
    await routeSync.runInitialSync(scope);
    final first = (await routes.fetchTodayRoutes())
        .when(success: (r) => r, failure: (_) => const []);

    await routeSync.runInitialSync(scope);
    final second = (await routes.fetchTodayRoutes())
        .when(success: (r) => r, failure: (_) => const []);

    expect(second.length, first.length);
    expect(
      second.expand((r) => r.stops).length,
      first.expand((r) => r.stops).length,
    );
  });
}
