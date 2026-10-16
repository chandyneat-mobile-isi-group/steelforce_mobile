import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Local-only reads, exactly like `order`'s `ProductRepository` — the sync
/// engine is the sole path data takes from remote into these tables.
abstract interface class RouteRepository {
  /// Not filtered by rep — the sync engine already scopes what lands
  /// locally to the signed-in rep's territory (`RouteSyncScope`), so every
  /// route that made it into the local DB is relevant to today's dashboard.
  ResultFuture<List<RoutePlan>> fetchTodayRoutes();

  /// Continuous stream of today's routes: emits the current local snapshot on
  /// listen, then re-emits whenever the routes change (a stop is checked
  /// in/out, a status update, or a background sync writes new data) — so the
  /// dashboard stays live without manual reloads.
  Stream<List<RoutePlan>> watchTodayRoutes();

  /// One-shot read of every locally-synced route regardless of date — the
  /// non-stream twin of [watchAllRoutes], used to re-read after a sync lands
  /// (sync writes through the local data source, which the broadcast stream
  /// doesn't observe). Backs the Stop Dashboard's multi-day view + calendar.
  ResultFuture<List<RoutePlan>> fetchAllRoutes();

  /// Continuous stream of every locally-synced route regardless of date —
  /// feeds the calendar's per-day route-count dots and lets a rep browse a
  /// different day's routes, neither of which [watchTodayRoutes] can answer
  /// since it's scoped to today only. Re-emits on the same triggers.
  Stream<List<RoutePlan>> watchAllRoutes();

  ResultFuture<RoutePlan> getRoute(String routeId);

  /// Re-reads the local routes and hands them to every open watcher, for a
  /// stop change written outside this repository (a discarded visit). Never
  /// fails: a read error keeps the watchers' last snapshot.
  Future<void> notifyStopsChanged();
  ResultFuture<void> updateRouteStatus(String routeId, RouteStatus status);
  ResultFuture<void> updateStopStatus(
    String stopId, {
    required VisitStatus status,
    DateTime? actualArrival,
    DateTime? actualDeparture,
  });
}
