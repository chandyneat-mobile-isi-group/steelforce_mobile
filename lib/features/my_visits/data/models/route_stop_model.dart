import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

class RouteStopModel extends RouteStop {
  const RouteStopModel({
    required super.id,
    required super.routeId,
    required super.depot,
    required super.sequence,
    required super.plannedArrival,
    required super.plannedDeparture,
    required super.status,
    super.visitSource,
    super.actualArrival,
    super.actualDeparture,
  });

  /// The remote payload only carries `depotId`; `depots` arrives as a
  /// flat de-duplicated list alongside it. The caller
  /// (`ApiRouteRemoteDataSource`) resolves the join and passes the full
  /// depot record in, so this model never needs its own lookup path.
  factory RouteStopModel.fromJson(DataMap json,
          {required DepotStopInfo depot}) =>
      RouteStopModel(
        id: json['id'] as String,
        routeId: json['routeId'] as String,
        depot: depot,
        sequence: (json['sequence'] as num).toInt(),
        // Null-tolerant, and this is load-bearing rather than defensive: an ad
        // hoc visit carries no planned window at all. Casting null to String
        // here threw inside the route sync *transaction*, so one unplanned stop
        // added by a colleague took down the rep's entire day — not one card.
        plannedArrival: _parseUtc(json['plannedArrival']),
        plannedDeparture: _parseUtc(json['plannedDeparture']),
        // Read the execution state the payload carries instead of hardcoding
        // `pending`. Hardcoding here meant the dashboard summary always computed
        // 0 completed / 0% progress regardless of the data — the "mock data
        // doesn't drive the UI" bug. Falls back to `pending` when absent so a
        // payload without a status still parses.
        status: VisitStatus.values.byNameOr(
            json['status'] as String?, VisitStatus.pending,
            context: 'stop.json.status'),
        // Falls back to `callPlan` on anything unrecognised — the documented
        // fallback. Reading an unknown origin as `adHoc` would show a planned
        // call as one the rep invented, which is the worse way to be wrong.
        visitSource: VisitSource.values.byNameOr(
            json['visitSource'] as String?, VisitSource.callPlan,
            context: 'stop.json.visitSource'),
        actualArrival: _parseUtc(json['actualArrival']),
        actualDeparture: _parseUtc(json['actualDeparture']),
      );

  factory RouteStopModel.fromRow(DataMap row, {required DepotStopInfo depot}) =>
      RouteStopModel(
        id: row['id'] as String,
        routeId: row['route_id'] as String,
        depot: depot,
        sequence: (row['sequence'] as num).toInt(),
        plannedArrival: _parseUtc(row['planned_arrival']),
        plannedDeparture: _parseUtc(row['planned_departure']),
        status: VisitStatus.values.byNameOr(
            row['status'] as String?, VisitStatus.values.first,
            context: 'stop.row.status'),
        visitSource: VisitSource.values.byNameOr(
            row['visit_source'] as String?, VisitSource.callPlan,
            context: 'stop.row.visitSource'),
        actualArrival: _parseUtc(row['actual_arrival']),
        actualDeparture: _parseUtc(row['actual_departure']),
      );

  DataMap toRow() => {
        'id': id,
        'route_id': routeId,
        'depot_id': depot.id,
        'sequence': sequence,
        'planned_arrival': plannedArrival?.toIso8601String(),
        'planned_departure': plannedDeparture?.toIso8601String(),
        'status': status.name,
        'visit_source': visitSource.name,
        'actual_arrival': actualArrival?.toIso8601String(),
        'actual_departure': actualDeparture?.toIso8601String(),
      };

  /// Parses a timestamp that may legitimately be absent.
  ///
  /// Tolerates a non-String too: a row read straight from Drift hands back a
  /// `DateTime`, and both shapes reach [RouteStopModel.fromRow] depending on
  /// which data source built the map.
  static DateTime? _parseUtc(Object? raw) => switch (raw) {
        null => null,
        final DateTime value => value,
        final String value when value.isNotEmpty => DateTime.tryParse(value),
        _ => null,
      };
}
