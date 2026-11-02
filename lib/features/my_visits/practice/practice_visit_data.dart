import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// The demo world a visit lesson runs over: one route for today with one
/// pending stop at the shared demo depot ([PracticeIds]).
abstract final class PracticeVisitData {
  /// The demo depot as a stop sees it.
  ///
  /// **No coordinates, on purpose.** A practice shop has no real place to stand
  /// in, so it carries no pin — and a depot without a pin is a case the real
  /// check-in rules already handle: `ActiveRouteBloc._onCheckIn` treats it as
  /// *unverifiable* and records the check-in with a warning instead of
  /// refusing it. The lesson passes through the real rules rather than a
  /// practice-only bypass.
  static const DepotStopInfo depot = DepotStopInfo(
    id: PracticeIds.depotId,
    name: PracticeIds.depotNameEn,
    nameKh: PracticeIds.depotNameKh,
    code: PracticeIds.depotCode,
    contact: '',
    phone: '',
    address: '',
    territory: '',
    territoryType: TerritoryType.urban,
    latitude: 0,
    longitude: 0,
  );

  /// Today's demo route, built against [now] so it is always "today".
  static RoutePlan route(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return RoutePlan(
      id: PracticeIds.routeId,
      name: PracticeIds.depotNameEn,
      repId: '',
      repName: '',
      territory: '',
      visitDate: day,
      plannedStart: day.add(const Duration(hours: 8)),
      plannedEnd: day.add(const Duration(hours: 17)),
      status: RouteStatus.published,
      stops: [
        RouteStop(
          id: PracticeIds.stopId,
          routeId: PracticeIds.routeId,
          depot: depot,
          sequence: 1,
          plannedArrival: day.add(const Duration(hours: 9)),
          plannedDeparture: day.add(const Duration(hours: 10)),
          status: VisitStatus.pending,
        ),
      ],
    );
  }
}
