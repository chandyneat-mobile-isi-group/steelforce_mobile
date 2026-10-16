import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

class RouteIdParams extends Equatable {
  const RouteIdParams(this.routeId);
  final String routeId;
  @override
  List<Object?> get props => [routeId];
}

class StopIdParams extends Equatable {
  const StopIdParams(this.stopId);
  final String stopId;
  @override
  List<Object?> get props => [stopId];
}

class UpdateStopStatusParams extends Equatable {
  const UpdateStopStatusParams({
    required this.stopId,
    required this.status,
    this.actualArrival,
    this.actualDeparture,
  });
  final String stopId;
  final VisitStatus status;
  final DateTime? actualArrival;
  final DateTime? actualDeparture;
  @override
  List<Object?> get props => [stopId, status, actualArrival, actualDeparture];
}

class UpdateRouteStatusParams extends Equatable {
  const UpdateRouteStatusParams(this.routeId, this.status);
  final String routeId;
  final RouteStatus status;
  @override
  List<Object?> get props => [routeId, status];
}
