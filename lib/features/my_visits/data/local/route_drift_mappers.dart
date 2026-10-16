import 'package:drift/drift.dart';
import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/route_dao.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_stop_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Drift row ↔ model mappers for the route aggregate (T1.5 cutover).
///
/// Mirrors `depot_drift_mappers.dart`. Mappers are the only code aware of
/// Drift row/companion shapes (ADR-003 point 2).

/// The geofence radius used when a depot's territory type is unknown.
///
/// **This is a fail-closed choice, not a convenience default.** `territory_type`
/// is nullable in `depots` (added in schema v7) and is populated by route
/// sync, so null means "route sync has not seen this depot yet". The value
/// drives the geofence radius, which is a fraud control
/// (`docs/blueprint/sync-architecture.md` §5 classifies check-ins as first-hand captures the
/// server cannot re-verify).
///
/// [TerritoryType.urban] is the **tightest** radius (50 m), so an unknown
/// territory rejects a check-in that a looser default would have waved through.
/// A wrongly-blocked rep is visible and recoverable in seconds; a wrongly-
/// accepted fraudulent check-in is neither.
const TerritoryType kUnknownTerritoryFallback = TerritoryType.urban;

extension RouteDepotRowStopInfoMapper on RouteDepotRow {
  /// Projects the route feed's own depot row onto the stop entity.
  ///
  /// A straight field copy: this table was defined to mirror the feed's
  /// `DepotStopInfo` payload (`docs/feature/my-visits/api.md` §7.1), so there is
  /// no vocabulary translation to do and nothing to reconcile.
  DepotStopInfoModel toStopInfo() => DepotStopInfoModel(
        id: id,
        name: name,
        nameKh: nameKh,
        code: code,
        contact: contact,
        phone: phone,
        address: address,
        territory: territory,
        territoryType: TerritoryType.values.asNameMap()[territoryType] ??
            kUnknownTerritoryFallback,
        latitude: latitude,
        longitude: longitude,
        geofenceRadiusOverride: geofenceRadiusOverride,
      );
}

extension DepotStopInfoRouteDepotMapper on DepotStopInfoModel {
  RouteDepotsCompanion toRouteDepotCompanion() => RouteDepotsCompanion.insert(
        id: id,
        name: name,
        nameKh: Value(nameKh),
        code: code,
        contact: contact,
        phone: phone,
        address: address,
        territory: territory,
        territoryType: territoryType.name,
        latitude: latitude,
        longitude: longitude,
        geofenceRadiusOverride: Value(geofenceRadiusOverride),
      );
}

extension DepotRowStopInfoMapper on Depot {
  /// Projects the depot directory row onto the slice route execution needs.
  ///
  /// Field names differ because the two tables were written years apart: the
  /// legacy `routes.db` copy called them `name`/`contact`, the directory calls
  /// them `shopName`/`ownerName`. Same data, and the directory is authoritative.
  DepotStopInfoModel toStopInfo() => DepotStopInfoModel(
        id: id,
        name: shopName,
        // Both languages ride along on the projection, so the stop card and
        // the depot card render the same shop identically after a language
        // switch. Projecting only `shopName` was why a Khmer session showed
        // Khmer in the directory and Latin on the route.
        nameKh: khName ?? '',
        code: depotCode,
        contact: ownerName,
        phone: phone,
        address: address,
        territory: territory,
        territoryType: territoryType == null
            ? kUnknownTerritoryFallback
            : TerritoryType.values.asNameMap()[territoryType!] ??
                kUnknownTerritoryFallback,
        latitude: latitude,
        longitude: longitude,
        geofenceRadiusOverride: geofenceRadiusOverride,
      );
}

extension RouteStopWithDepotMapper on RouteStopWithDepot {
  /// Builds the stop, standing in for a depot row the feed did not send.
  ///
  /// The route feed is documented to include every stop's depot
  /// (`docs/feature/my-visits/api.md` §5.1), so [depot] being null means the
  /// server broke its own contract. The stop is still rendered rather than
  /// dropped — dropping it is the data loss ADR-011 exists to stop — using the
  /// depot id as both name and code, which reads unmistakably as "details
  /// missing" while staying actionable: the rep can still match the code, open
  /// the stop and check in.
  ///
  /// The geofence falls back to [kUnknownTerritoryFallback] (urban, 50 m), the
  /// tightest radius, so an unknown location fails closed.
  DepotStopInfoModel get _depotOrPlaceholder =>
      depot?.toStopInfo() ??
      DepotStopInfoModel(
        id: stop.depotId,
        name: stop.depotId,
        code: stop.depotId,
        contact: '',
        phone: '',
        address: '',
        territory: '',
        territoryType: kUnknownTerritoryFallback,
        latitude: 0,
        longitude: 0,
      );

  RouteStopModel toModel() => RouteStopModel(
        id: stop.id,
        routeId: stop.routeId,
        depot: _depotOrPlaceholder,
        sequence: stop.sequence,
        // Null for an ad hoc visit, and carried through as null rather than
        // substituted — the UI decides what "no planned window" looks like.
        plannedArrival: stop.plannedArrival,
        plannedDeparture: stop.plannedDeparture,
        // An unrecognised status means a build downgrade or a corrupt row.
        // Falling back to `pending` keeps the stop visible and actionable
        // rather than crashing the whole route screen.
        status: VisitStatus.values.asNameMap()[stop.status] ??
            VisitStatus.values.first,
        // A row written before v25 has the column default, `callPlan`, which
        // is what those stops all were.
        visitSource: VisitSource.values.byNameOr(
            stop.visitSource, VisitSource.callPlan,
            context: 'stop.row.visitSource'),
        actualArrival: stop.actualArrival,
        actualDeparture: stop.actualDeparture,
      );
}

extension RouteRowMapper on RouteRow {
  RoutePlanModel toModel(List<RouteStop> stops) => RoutePlanModel(
        id: id,
        name: name,
        repId: repId,
        repName: repName,
        territory: territory,
        visitDate: visitDate,
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
        status:
            RouteStatus.values.asNameMap()[status] ?? RouteStatus.values.first,
        stops: stops,
      );
}

extension RoutePlanModelMapper on RoutePlanModel {
  RoutesCompanion toCompanion() => RoutesCompanion.insert(
        id: id,
        name: name,
        repId: repId,
        repName: repName,
        territory: territory,
        visitDate: visitDate,
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
        status: status.name,
        // A plan arriving from SAP is already in step with the server; it is not
        // a local capture awaiting a push. Only local mutations mark dirty.
        syncState: const Value('synced'),
        dirty: const Value(false),
      );

  List<RouteStopsCompanion> toStopCompanions() =>
      stops.map((s) => s.toCompanion(id)).toList();
}

extension RouteStopEntityMapper on RouteStop {
  RouteStopsCompanion toCompanion(String routeId) => RouteStopsCompanion.insert(
        id: id,
        routeId: routeId,
        depotId: depot.id,
        sequence: sequence,
        plannedArrival: Value(plannedArrival),
        plannedDeparture: Value(plannedDeparture),
        status: status.name,
        visitSource: Value(visitSource.name),
        actualArrival: Value(actualArrival),
        actualDeparture: Value(actualDeparture),
        syncState: const Value('synced'),
        dirty: const Value(false),
      );
}
