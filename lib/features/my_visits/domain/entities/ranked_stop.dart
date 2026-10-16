import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';

/// A [RouteStop] stamped with its straight-line distance from the rep's current
/// location (null when location is unavailable). Output of [StopDistanceSorter].
class RankedStop extends Equatable {
  const RankedStop({required this.stop, this.distanceMeters});

  final RouteStop stop;
  final double? distanceMeters;

  @override
  List<Object?> get props => [stop, distanceMeters];
}
