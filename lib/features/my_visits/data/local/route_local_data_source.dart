import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

abstract interface class RouteLocalDataSource {
  Future<List<RoutePlanModel>> fetchTodayRoutes();

  /// Every locally-synced route regardless of date — feeds the calendar's
  /// per-day route-count dots and date-selection browsing.
  Future<List<RoutePlanModel>> fetchAllRoutes();
  Future<RoutePlanModel?> getRoute(String routeId);
  Future<void> updateRouteStatus(String routeId, RouteStatus status);
  Future<void> updateStopStatus(
    String stopId, {
    required VisitStatus status,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  });

  Future<void> upsertDepots(List<DepotStopInfoModel> depots);
  Future<void> upsertRoutes(List<RoutePlanModel> routes);

  Future<DateTime?> getLastSyncedAt(String entity);
  Future<void> setLastSyncedAt(String entity, DateTime at);
}

// ─────────────────────────────────────────────────────────────────────────────
// The legacy sqflite `RouteLocalDataSourceImpl` was removed by T1.5b.
//
// It had been retained-but-unregistered as a rollback path after the T1.5 Drift
// cutover. T1.5b removes the last reader of the plaintext `routes.db`, so the
// rollback target no longer exists — and because it imported `sqflite`, which
// has no web implementation, keeping dead code here would have blocked the web
// target permanently (`docs/blueprint/web-architecture.md`).
//
// The live implementation is `RouteDriftLocalDataSource`, registered in
// `my_visits_injection.dart`. The deleted class remains in git history.
// ─────────────────────────────────────────────────────────────────────────────
