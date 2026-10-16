import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';

class RoutePlanModel extends RoutePlan {
  const RoutePlanModel({
    required super.id,
    required super.name,
    required super.repId,
    required super.repName,
    required super.territory,
    required super.visitDate,
    required super.plannedStart,
    required super.plannedEnd,
    required super.status,
    required super.stops,
  });

  factory RoutePlanModel.fromJson(DataMap json,
          {required List<RouteStop> stops}) =>
      RoutePlanModel(
        id: json['id'] as String,
        name: json['name'] as String,
        repId: json['repId'] as String,
        repName: json['repName'] as String,
        territory: json['territory'] as String,
        visitDate: DateTime.parse(json['visitDate'] as String),
        plannedStart: DateTime.parse(json['plannedStart'] as String),
        plannedEnd: DateTime.parse(json['plannedEnd'] as String),
        // Read the route's own state rather than assuming `published`, so a
        // day's mix of completed / in-progress / planned routes survives into
        // the UI. Falls back to `published` when the payload omits it.
        status: json['status'] != null
            ? RouteStatus.values.asNameMap()[json['status']] ??
                RouteStatus.published
            : RouteStatus.published,
        stops: stops,
      );

  factory RoutePlanModel.fromRow(DataMap row,
          {required List<RouteStop> stops}) =>
      RoutePlanModel(
        id: row['id'] as String,
        name: row['name'] as String,
        repId: row['rep_id'] as String,
        repName: row['rep_name'] as String,
        territory: row['territory'] as String,
        visitDate: DateTime.parse(row['visit_date'] as String),
        plannedStart: DateTime.parse(row['planned_start'] as String),
        plannedEnd: DateTime.parse(row['planned_end'] as String),
        status: RouteStatus.values.byNameOr(
            row['status'] as String?, RouteStatus.values.first,
            context: 'route.row.status'),
        stops: stops,
      );

  DataMap toRow() => {
        'id': id,
        'name': name,
        'rep_id': repId,
        'rep_name': repName,
        'territory': territory,
        'visit_date': visitDate.toIso8601String(),
        'planned_start': plannedStart.toIso8601String(),
        'planned_end': plannedEnd.toIso8601String(),
        'status': status.name,
      };
}
