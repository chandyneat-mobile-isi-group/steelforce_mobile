import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';

enum RouteStatus { planned, published, inProgress, completed }

class RoutePlan extends Equatable {
  const RoutePlan({
    required this.id,
    required this.name,
    required this.repId,
    required this.repName,
    required this.territory,
    required this.visitDate,
    required this.plannedStart,
    required this.plannedEnd,
    required this.status,
    required this.stops,
  });

  final String id;
  final String name;
  final String repId;
  final String repName;
  final String territory;
  final DateTime visitDate;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final RouteStatus status;
  final List<RouteStop> stops;

  int get totalStops => stops.length;
  int get completedStops => stops.where((s) => s.status.isComplete).length;
  int get missedStops => stops.where((s) => s.status.name == 'missed').length;
  double get progress => totalStops == 0 ? 0 : completedStops / totalStops;

  RoutePlan copyWith({RouteStatus? status, List<RouteStop>? stops}) =>
      RoutePlan(
        id: id,
        name: name,
        repId: repId,
        repName: repName,
        territory: territory,
        visitDate: visitDate,
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
        status: status ?? this.status,
        stops: stops ?? this.stops,
      );

  @override
  List<Object?> get props =>
      [id, name, repId, territory, visitDate, status, stops];
}
