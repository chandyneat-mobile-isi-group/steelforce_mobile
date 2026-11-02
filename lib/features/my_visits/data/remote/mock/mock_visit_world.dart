// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
//
// The demo backend's memory for My Visits: the rep's plans for this week,
// built against the clock so "today" is always today, and every change a
// check-in, check-out, skip or ad hoc start makes to them.
//
// Every My Visits mock data source reads and writes this one instance, the
// way the real endpoints all read one database: a plan checked in through
// the Plans API reads as checked in on the next list load, on the route
// pull, and in a visit push. In memory only — a page reload starts the demo
// day over.
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// One demo depot, matching the depots feature's demo book by [code].
class MockVisitDepot {
  const MockVisitDepot(this.code, this.name, this.latitude, this.longitude);

  /// Both the depot code a plan names and the depot id a route stop carries.
  final String code;
  final String name;
  final double latitude;
  final double longitude;
}

/// One visit on the demo plan. [status] moves as the rep works it.
class MockVisitRecord {
  MockVisitRecord({
    required this.id,
    required this.day,
    required this.depot,
    required this.status,
    this.adHoc = false,
  });

  final String id;

  /// Local midnight of the day the visit is assigned to.
  final DateTime day;
  final MockVisitDepot depot;
  final bool adHoc;
  VisitPlanStatus status;

  /// The check-in that opened this visit, and when it was in and out.
  String? checkInId;
  DateTime? checkedInAt;
  DateTime? checkedOutAt;

  bool get isOpen =>
      status == VisitPlanStatus.planned ||
      status == VisitPlanStatus.draft ||
      status == VisitPlanStatus.checkedIn;

  /// Records a check-in. A second one for the same visit changes nothing.
  void checkIn(String id, DateTime at) {
    if (status == VisitPlanStatus.checkedIn ||
        status == VisitPlanStatus.completed) {
      return;
    }
    status = VisitPlanStatus.checkedIn;
    checkInId = id;
    checkedInAt = at.toUtc();
  }

  /// Records a check-out. Accepted without a check-in, as the server does.
  void checkOut(DateTime at) {
    if (status == VisitPlanStatus.completed) return;
    status = VisitPlanStatus.completed;
    checkedOutAt = at.toUtc();
  }

  VisitPlan toEntity() => VisitPlan(
        id: id,
        assignmentDate: day,
        visitType: adHoc ? 'AdHoc' : 'Planned',
        outletType: 'Depot',
        status: status,
        rawStatus: _rawStatus(status),
        depotCode: depot.code,
        outletName: depot.name,
        depotName: depot.name,
        depotType: 'Depot',
        territoryCode: MockVisitWorld.territory,
        latitude: depot.latitude,
        longitude: depot.longitude,
      );

  /// The server's word: `Planned`, `CheckedIn`, `Completed`, …
  static String _rawStatus(VisitPlanStatus status) =>
      '${status.name[0].toUpperCase()}${status.name.substring(1)}';
}

class MockVisitWorld {
  MockVisitWorld({DateTime Function() clock = DateTime.now}) : _clock = clock;

  final DateTime Function() _clock;

  static const String repId = 'demo-rep-001';
  static const String repName = 'Sokha Chan';
  static const String territory = 'PP-01';

  /// The demo depot book, in the order the depots feature lists it.
  static const List<MockVisitDepot> depots = [
    MockVisitDepot('DPT-DEMO-001', 'Mekong Steel Supply', 11.6020, 104.9010),
    MockVisitDepot(
        'DPT-DEMO-002', 'Angkor Building Materials', 11.5900, 104.8650),
    MockVisitDepot('DPT-DEMO-003', 'Golden Roof Hardware', 11.5480, 104.9450),
    MockVisitDepot('DPT-DEMO-004', 'Sovann Iron Works', 11.5300, 104.9100),
    MockVisitDepot(
        'DPT-DEMO-005', 'Riverside Construction Depot', 11.5950, 104.9250),
    MockVisitDepot('DPT-DEMO-006', 'Bayon Steel & Pipe', 11.5750, 104.8950),
    MockVisitDepot(
        'DPT-DEMO-007', 'Prey Veng Road Hardware', 11.5100, 104.8800),
    MockVisitDepot('DPT-DEMO-008', 'Lotus Metal Trading', 11.5550, 104.8300),
  ];

  /// Days relative to today, each with its depots (1-based, as listed in
  /// [depots]) in visiting order. Today is stops 1, 6, 2, 5 — the first
  /// already done; the rest of the week uses the other depots.
  static const List<({int offset, List<int> stops})> _week = [
    (offset: -2, stops: [3, 4]),
    (offset: -1, stops: [7, 8]),
    (offset: 0, stops: [1, 6, 2, 5]),
    (offset: 1, stops: [3, 7]),
    (offset: 2, stops: [4, 8]),
    (offset: 3, stops: [3, 8]),
  ];

  late final List<MockVisitRecord> _visits = _seed();

  DateTime now() => _clock();

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Every visit, by day then visiting order.
  List<MockVisitRecord> get visits => List.unmodifiable(_visits);

  /// The visits [period] covers, in the business day's terms.
  List<MockVisitRecord> visitsIn(PlanPeriod period) {
    final (from, to) = window(period);
    return [
      for (final v in _visits)
        if (!v.day.isBefore(from) && !v.day.isAfter(to)) v,
    ];
  }

  /// First and last day of [period], local midnight.
  (DateTime, DateTime) window(PlanPeriod period) {
    final day = today;
    return switch (period) {
      PlanPeriod.today => (day, day),
      PlanPeriod.thisWeek => (
          day.subtract(Duration(days: day.weekday - 1)),
          day.add(Duration(days: DateTime.daysPerWeek - day.weekday)),
        ),
      PlanPeriod.thisMonth => (
          DateTime(day.year, day.month),
          DateTime(day.year, day.month + 1, 0),
        ),
    };
  }

  MockVisitDepot? depotByCode(String? code) =>
      depots.where((d) => d.code == code?.trim()).firstOrNull;

  MockVisitRecord? find(String id) =>
      _visits.where((v) => v.id == id).firstOrNull;

  /// The visit [id], or the server's 404 for a plan it does not hold.
  MockVisitRecord require(String id) =>
      find(id) ??
      (throw refusal('PLAN_NOT_FOUND', 404, 'This visit is not on your plan.'));

  /// A Draft ad hoc visit for today at [depot], under the id the app chose.
  MockVisitRecord addAdHoc(String id, MockVisitDepot depot) {
    final visit = MockVisitRecord(
      id: id,
      day: today,
      depot: depot,
      status: VisitPlanStatus.draft,
      adHoc: true,
    );
    _visits.add(visit);
    return visit;
  }

  /// A refusal shaped like the server's: [code] as both the code and the
  /// server code, so `AdHocPlanStarts.codeOf` and the failure mapping read
  /// it the way they read a live one.
  static ApiException refusal(String code, int status, String message,
          {Map<String, dynamic>? details}) =>
      ApiException(ApiError(
        code: code,
        serverCode: code,
        statusCode: status,
        message: message,
        details: details,
      ));

  List<MockVisitRecord> _seed() {
    final day = today;
    return [
      for (final d in _week)
        for (var i = 0; i < d.stops.length; i++)
          MockVisitRecord(
            id: 'demo-plan-${_stamp(day, d.offset)}-${i + 1}',
            day: DateTime(day.year, day.month, day.day + d.offset),
            depot: depots[d.stops[i] - 1],
            status: _seedStatus(d.offset, i),
          ),
    ];
  }

  /// Past days are done (one missed call, so the week reads like a real
  /// one); today's first stop is done; everything else is still to do.
  static VisitPlanStatus _seedStatus(int offset, int index) {
    if (offset < 0) {
      return offset == -1 && index == 1
          ? VisitPlanStatus.missed
          : VisitPlanStatus.completed;
    }
    if (offset == 0 && index == 0) return VisitPlanStatus.completed;
    return VisitPlanStatus.planned;
  }

  static String _stamp(DateTime today, int offset) {
    final d = DateTime(today.year, today.month, today.day + offset);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}';
  }
}
