/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// The rep's route set as `GET /mobile/visits/routes` would send it
/// (`docs/feature/my-visits/api.md` §5): today's Call Plan on
/// [DemoSeed.todayStops], two completed days behind it and two planned days
/// ahead, built fresh against the clock so "today" is always today.
///
/// Every depot is a [DemoSeed] depot — fictitious names, `0xx 000 xxx`
/// numbers, invented contacts.
library;

import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';

/// Route-name key the dashboard renders through `.tr`.
const String _routeNameKey = 'my_visits.route_info.plan_daily';

const String _defaultTerritory = 'PP-CENTRAL';

/// One planned day: its offset from today, the depots in visiting order, and
/// how far the day got.
typedef _Day = ({int offset, List<int> depotIndexes, String status});

const List<_Day> _days = [
  (offset: -2, depotIndexes: [10, 11, 2], status: 'completed'),
  (offset: -1, depotIndexes: [6, 7, 8, 9], status: 'completed'),
  (offset: 0, depotIndexes: [0, 1, 2, 3, 4, 5], status: 'published'),
  (offset: 1, depotIndexes: [6, 7, 8], status: 'published'),
  (offset: 2, depotIndexes: [9, 10, 11], status: 'planned'),
];

class DemoRouteFixtures {
  const DemoRouteFixtures(this._ledger);

  final DemoVisitLedger _ledger;

  /// The UTC calendar day the route feed is anchored to, matching
  /// `RouteDao.fetchRoutesForDay` (see `route_feed_fixture.dart`).
  static DateTime utcDay(DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  /// `YYYY-MM-DD` of [day].
  static String dateKey(DateTime day) => day.toIso8601String().split('T').first;

  static String routeIdFor(DateTime day, int offset) => offset == 0
      ? DemoSeed.todayRouteId
      : 'demo-route-${dateKey(day).replaceAll('-', '')}';

  /// Every route, oldest day first.
  List<DataMap> routes({required String territory}) {
    final today = utcDay(_ledger.now());
    return [
      for (final d in _days)
        _route(today.add(Duration(days: d.offset)), d, territory),
    ];
  }

  /// The `customers` record for one demo depot.
  static DataMap depotJson(DemoDepot depot, {required String territory}) {
    return {
      'id': depot.id,
      'name': depot.name,
      'nameKh': depot.nameKm,
      'code': depot.code,
      'contact': depot.ownerName,
      'phone': depot.phone,
      'address': '${depot.district}, ${depot.province}',
      'territory': territory,
      'territoryType': depot.province == 'Phnom Penh' ? 'urban' : 'suburban',
      'latitude': depot.latitude,
      'longitude': depot.longitude,
      'geofenceRadiusOverride': null,
    };
  }

  static String territoryOr(String requested) =>
      requested.isEmpty ? _defaultTerritory : requested;

  DataMap _route(DateTime day, _Day d, String territory) {
    final routeId = routeIdFor(day, d.offset);
    final stamp = dateKey(day).replaceAll('-', '');
    final stops = <DataMap>[
      for (var i = 0; i < d.depotIndexes.length; i++)
        _stop(
          id: '$kDemoStopIdPrefix$stamp-${i + 1}',
          routeId: routeId,
          depot: DemoSeed.depots[d.depotIndexes[i]],
          sequence: i + 1,
          plannedArrival: _localTime(day, 8, i * 75),
          pastStatus: d.status == 'completed'
              // One missed call on the busiest past day, so history reads
              // like a real week rather than a perfect one.
              ? (d.offset == -1 && i == 2 ? 'missed' : 'checkedOut')
              : null,
        ),
      if (d.offset == 0) ..._ledger.adHocStopsOn(dateKey(day)),
    ];
    return {
      'id': routeId,
      'name': _routeNameKey,
      'repId': DemoSeed.repId,
      'repName': DemoSeed.repName,
      'territory': territory,
      'visitDate': day.toIso8601String(),
      'plannedStart': _localTime(day, 8, 0).toIso8601String(),
      'plannedEnd': _localTime(day, 17, 0).toIso8601String(),
      'status': _routeStatus(d.status, stops),
      'stops': stops,
    };
  }

  DataMap _stop({
    required String id,
    required String routeId,
    required DemoDepot depot,
    required int sequence,
    required DateTime plannedArrival,
    required String? pastStatus,
  }) {
    final plannedDeparture = plannedArrival.add(const Duration(minutes: 45));
    final recorded = _ledger.execution(id);
    final visited = pastStatus == 'checkedOut';
    return {
      'id': id,
      'routeId': routeId,
      'customerId': depot.id,
      'sequence': sequence,
      'plannedArrival': plannedArrival.toIso8601String(),
      'plannedDeparture': plannedDeparture.toIso8601String(),
      'status': recorded?.status ?? pastStatus ?? 'pending',
      'visitSource': 'callPlan',
      'actualArrival': recorded?.arrival ??
          (visited
              ? plannedArrival.add(const Duration(minutes: 6)).toIso8601String()
              : null),
      'actualDeparture': recorded?.departure ??
          (visited
              ? plannedDeparture
                  .add(const Duration(minutes: 4))
                  .toIso8601String()
              : null),
    };
  }

  /// Today's route moves from published to in progress to completed as the
  /// rep works it; other days keep their fixed state.
  static String _routeStatus(String planned, List<DataMap> stops) {
    if (planned != 'published' || stops.isEmpty) return planned;
    final statuses = stops.map((s) => s['status']).toList();
    if (statuses.every((s) => s == 'checkedOut')) return 'completed';
    if (statuses.any((s) => s == 'checkedIn' || s == 'checkedOut')) {
      return 'inProgress';
    }
    return planned;
  }

  /// [hour]:00 plus [minutes] on [day]'s calendar date in the device's zone,
  /// as UTC — a rep's plan is drawn in local working hours.
  static DateTime _localTime(DateTime day, int hour, int minutes) =>
      DateTime(day.year, day.month, day.day, hour, minutes).toUtc();
}
