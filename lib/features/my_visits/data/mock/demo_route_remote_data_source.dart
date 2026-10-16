/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// [RouteRemoteDataSource] for a demo build: answers the route pull from
/// [DemoRouteFixtures] instead of `GET /mobile/visits/routes`.
///
/// Parses through the same `fromJson` factories as [ApiRouteRemoteDataSource],
/// with the same depot/stop join, so the demo exercises the real models.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_route_fixtures.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_stop_model.dart';
import 'package:steelforce/features/my_visits/data/remote/route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/route_sync_page.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/core/demo/demo_seed.dart';

class DemoRouteRemoteDataSource implements RouteRemoteDataSource {
  DemoRouteRemoteDataSource(this._network, this._ledger)
      : _fixtures = DemoRouteFixtures(_ledger);

  final DemoNetwork _network;
  final DemoVisitLedger _ledger;
  final DemoRouteFixtures _fixtures;

  /// 0-based, like the interface (the live adapter converts to the API's
  /// 1-based paging; there is no wire here to convert for).
  @override
  Future<RouteSyncPage> fetchInitial({
    required RouteSyncScope scope,
    required int page,
    required int pageSize,
  }) async {
    await _network.roundTrip();
    final territory = DemoRouteFixtures.territoryOr(scope.territory);
    final all = _fixtures.routes(territory: territory);
    final start = (page * pageSize).clamp(0, all.length);
    final end = (start + pageSize).clamp(0, all.length);
    return _page(all.sublist(start, end),
        territory: territory, hasMore: end < all.length);
  }

  /// The rep's complete current set, which the contract permits a delta to
  /// return every time (api.md §5.2) and the repository absorbs.
  @override
  Future<RouteSyncPage> fetchDelta({
    required RouteSyncScope scope,
    required DateTime since,
  }) async {
    await _network.roundTrip();
    final territory = DemoRouteFixtures.territoryOr(scope.territory);
    return _page(_fixtures.routes(territory: territory),
        territory: territory, hasMore: false);
  }

  RouteSyncPage _page(
    List<DataMap> routesJson, {
    required String territory,
    required bool hasMore,
  }) {
    final depots = <String, DepotStopInfoModel>{};
    for (final route in routesJson) {
      for (final stop in route['stops'] as List<DataMap>) {
        final id = stop['customerId'] as String;
        final depot = DemoSeed.depotById(id);
        if (depot == null) continue;
        depots[id] ??= DepotStopInfoModel.fromJson(
            DemoRouteFixtures.depotJson(depot, territory: territory));
      }
    }

    final routes = [
      for (final route in routesJson)
        RoutePlanModel.fromJson(route, stops: [
          for (final stop in route['stops'] as List<DataMap>)
            if (depots[stop['customerId']] case final depot?)
              RouteStopModel.fromJson(stop, depot: depot),
        ]),
    ];

    return RouteSyncPage(
      depots: depots.values.toList(),
      routes: routes,
      generatedAt: _ledger.now().toUtc(),
      territories: [territory],
      hasMore: hasMore,
    );
  }
}
