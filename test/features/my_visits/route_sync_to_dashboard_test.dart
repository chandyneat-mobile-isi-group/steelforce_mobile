import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/local/depot_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/api_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';

import 'route_feed_fixture.dart';

/// End-to-end from the route feed to what the Visit dashboards actually read.
///
/// Every other route test in this folder seeds the DAO directly, which skips
/// the path that broke in the field: the rep opens My Visits and gets empty
/// screens. A test that hands the database its rows can never catch that, so
/// this one starts where the app does — at the remote feed, and drives the
/// real [ApiRouteRemoteDataSource] over a scripted transport so the JSON the
/// backend actually sends is parsed on the way through.
class _AlwaysOnline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  late AppDatabase db;
  late RouteDriftLocalDataSource local;
  late DepotDriftLocalDataSource depots;
  late RouteSyncRepositoryImpl sync;
  late RouteRepositoryImpl routes;

  const logger = ConsoleAppLogger(verbose: false);
  const scope = RouteSyncScope(repId: 'rep-1', territory: 'Phnom Penh');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    depots = DepotDriftLocalDataSource(db.depotDao);
    local = RouteDriftLocalDataSource(db.routeDao, logger);
    // Resolved per request, so the feed names whatever depots the test
    // seeded — `route_stops.depot_id` is a live FK.
    sync = RouteSyncRepositoryImpl(
      remote: ApiRouteRemoteDataSource(
        scriptedRouteFeed(
          depotIds: () async => (await depots.browse(page: 0, pageSize: 12))
              .map((c) => c.id)
              .toList(),
        ),
      ),
      local: local,
      network: _AlwaysOnline(),
    );
    routes = RouteRepositoryImpl(local);
  });
  tearDown(() => db.close());

  /// The route feed rebases its stops onto the rep's real depot directory
  /// (`route_stops.depot_id` is a live FK), so the directory has to exist
  /// before any route can be pulled.
  Future<void> seedDepots({int count = 12}) async {
    final now = DateTime.now().toUtc();
    for (var i = 0; i < count; i++) {
      await db.into(db.depots).insert(
            DepotsCompanion.insert(
              id: 'cust-$i',
              sapDepotId: Value('SAP-$i'),
              depotCode: 'C-$i',
              shopName: 'ISI Hardware $i',
              ownerName: 'Sok Dara',
              phone: '012345678',
              address: 'St 271',
              province: 'Phnom Penh',
              district: 'TK',
              territory: 'Phnom Penh',
              latitude: 11.55,
              longitude: 104.91,
              creditLimit: 5000,
              status: 'active',
              assignedRepId: 'rep-1',
              assignedRepName: 'Rep One',
              updatedAt: now,
              territoryType: const Value('industrial'),
            ),
          );
    }
  }

  test('a route whose depots are absent from the directory still syncs',
      () async {
    // Reverses what this test used to assert (ADR-011).
    //
    // It previously required this sync to FAIL, because route stops carried a
    // foreign key into the depot directory and the feed "cannot invent
    // depots". That framing made an ordinary condition fatal: the route and
    // depot endpoints are separate, independently-paged, and separately
    // scoped, so a stop referencing a depot the directory has not pulled is
    // routine — and failing meant the rep got no route at all.
    //
    // The feed carries its own depot rows, so it is self-sufficient. The
    // directory is left empty here on purpose.
    final independent = RouteSyncRepositoryImpl(
      remote: ApiRouteRemoteDataSource(unsatisfiableRouteFeed()),
      local: local,
      network: _AlwaysOnline(),
    );

    final result = await independent.runInitialSync(scope);

    expect(result.when(success: (_) => true, failure: (_) => false), isTrue,
        reason: 'the rep must get their route regardless of directory state');

    final today = (await routes.fetchTodayRoutes())
        .when(success: (r) => r, failure: (_) => const []);
    expect(today, isNotEmpty,
        reason: 'and the route must actually reach the dashboard');
  });

  test('today routes reach the dashboard after a sync', () async {
    await seedDepots();

    final result = await sync.runInitialSync(scope);
    final upserted = result.when(success: (r) => r.upserted, failure: (_) => 0);
    expect(upserted, greaterThan(0), reason: 'the feed produced no routes');

    final today = (await routes.fetchTodayRoutes())
        .when(success: (r) => r, failure: (_) => const []);

    expect(today, isNotEmpty,
        reason: 'this is the empty Visit dashboard: sync reported routes, so '
            "today's list must return them");
  });

  test('synced routes carry stops with depot information', () async {
    await seedDepots();
    await sync.runInitialSync(scope);

    final today = (await routes.fetchTodayRoutes())
        .when(success: (r) => r, failure: (_) => const []);

    expect(today.any((r) => r.stops.isNotEmpty), isTrue,
        reason: 'a route with no stops renders as an empty Stop Dashboard');

    final stop = today.firstWhere((r) => r.stops.isNotEmpty).stops.first;
    expect(stop.depot.name.trim(), isNotEmpty);
  });
}
