import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// One stop on a route, denormalized with its [depot] the same
/// way `order`'s `Product` is a joined read-model — the UI never has to
/// separately look up the depot for a stop.
class RouteStop extends Equatable {
  const RouteStop({
    required this.id,
    required this.routeId,
    required this.depot,
    required this.sequence,
    required this.plannedArrival,
    required this.plannedDeparture,
    required this.status,
    this.visitSource = VisitSource.callPlan,
    this.actualArrival,
    this.actualDeparture,
  });

  final String id;
  final String routeId;
  final DepotStopInfo depot;

  /// Ordering position. Call Plan stops occupy 1..100; ad hoc visits are
  /// banded at **1001 and above**, which is why sorting by this alone already
  /// puts them last and no partition or second list is needed.
  ///
  /// **Never render the raw number.** 1001 is an ordering device, not a
  /// position the rep should read — show an "ad hoc" chip instead.
  final int sequence;

  /// Null on an ad hoc visit — nobody planned it, and the backend refuses to
  /// invent a window rather than fabricate one the rep would be measured
  /// against. Always present on a Call Plan stop.
  ///
  /// Every read site has to decide what "no planned time" looks like, and the
  /// right answer is almost always *show nothing* rather than *substitute
  /// something*: hide the time row, skip the running-late check, contribute
  /// zero to a day-duration sum.
  final DateTime? plannedArrival;
  final DateTime? plannedDeparture;

  final VisitStatus status;

  /// Where this stop came from. Defaulted so every existing construction site
  /// still compiles — which is also what the server does for every row written
  /// before the feature existed. See [VisitSource].
  final VisitSource visitSource;

  final DateTime? actualArrival;
  final DateTime? actualDeparture;

  /// True when the rep added this stop themselves rather than the Call Plan
  /// issuing it. An ad hoc visit walks the same lifecycle as any other stop.
  bool get isAdHoc => visitSource == VisitSource.adHoc;

  /// True when this stop carries a planned window at all — the one check every
  /// time-rendering site should make before formatting anything.
  bool get hasPlannedWindow => plannedArrival != null;

  RouteStop copyWith(
          {VisitStatus? status,
          DateTime? actualArrival,
          DateTime? actualDeparture}) =>
      RouteStop(
        id: id,
        routeId: routeId,
        depot: depot,
        sequence: sequence,
        plannedArrival: plannedArrival,
        plannedDeparture: plannedDeparture,
        status: status ?? this.status,
        visitSource: visitSource,
        actualArrival: actualArrival ?? this.actualArrival,
        actualDeparture: actualDeparture ?? this.actualDeparture,
      );

  @override
  List<Object?> get props => [
        id,
        routeId,
        depot,
        sequence,
        plannedArrival,
        status,
        visitSource,
        actualArrival,
        actualDeparture
      ];
}
