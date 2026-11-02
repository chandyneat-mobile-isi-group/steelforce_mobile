// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
//
// [VisitPlanRemoteDataSource] for the static web demo: the Plans API answered
// from [MockVisitWorld], with no network call.
//
// Keeps the rules a presenter would notice the live server enforcing — only
// today's visits start or skip, a closed visit cannot be checked in again,
// one ad hoc visit per depot a day — and refuses with the same codes, so the
// repository's real failure mapping runs.
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_world.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/ad_hoc_plan_starts.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';

class MockVisitPlanRemoteDataSource implements VisitPlanRemoteDataSource {
  MockVisitPlanRemoteDataSource(this._world);

  final MockVisitWorld _world;

  /// Ad hoc ids already answered, so a retry of the same start is a 200
  /// with the same visit rather than a second one.
  final Set<String> _adHocIds = {};

  @override
  Future<VisitPlansOverview> fetchMyPlans(PlanPeriod period) async {
    await MockLatency.tick();
    return _overview(period);
  }

  @override
  Future<VisitPlansOverview> fetchTodayPlans() async {
    await MockLatency.tick();
    return _overview(PlanPeriod.today);
  }

  @override
  Future<void> skipPlan(String planId, String reason) async {
    await MockLatency.tick();
    final visit = _todayVisit(planId);
    if (visit.adHoc ||
        (visit.status != VisitPlanStatus.planned &&
            visit.status != VisitPlanStatus.checkedIn)) {
      throw _conflict();
    }
    visit.status = VisitPlanStatus.skipped;
  }

  @override
  Future<PlanCheckInTarget> fetchCheckInTarget(String planId) async {
    await MockLatency.tick();
    final visit = _world.require(planId);
    return PlanCheckInTarget(
      planId: visit.id,
      status: visit.status,
      depotCode: visit.depot.code,
      depotName: visit.depot.name,
      depotLatitude: visit.depot.latitude,
      depotLongitude: visit.depot.longitude,
      radiusMeters: PlanCheckInTarget.defaultRadiusMeters,
    );
  }

  @override
  Future<PlanCheckInResult> checkIn(PlanCheckInRequest request) async {
    await MockLatency.tick();
    final visit = _todayVisit(request.planId);
    final distance = GeofenceService.distanceMeters(request.latitude,
        request.longitude, visit.depot.latitude, visit.depot.longitude);
    final inside = distance <= PlanCheckInTarget.defaultRadiusMeters;
    switch (visit.status) {
      case VisitPlanStatus.planned || VisitPlanStatus.draft:
        if (!inside && request.reason == null) {
          throw MockVisitWorld.refusal(planCheckInReasonRequiredCode, 422,
              'You are outside the depot zone. Give a reason.');
        }
        visit.checkIn(request.checkInId, _world.now());
      case VisitPlanStatus.checkedIn:
        break; // The same check-in again: answered, not recorded twice.
      default:
        throw _conflict();
    }
    return PlanCheckInResult(
      checkInId: request.checkInId,
      zone: inside ? 'InsideZone' : 'OutsideZone',
      distanceMeters: distance,
    );
  }

  @override
  Future<void> uploadInventoryPhotos(PlanInventoryUploadRequest request) async {
    await MockLatency.tick();
    final visit = _world.require(request.planId);
    if (visit.status != VisitPlanStatus.checkedIn) throw _conflict();
  }

  @override
  Future<void> checkOut(PlanCheckOutRequest request) async {
    await MockLatency.tick();
    final visit = _world.require(request.planId);
    switch (visit.status) {
      case VisitPlanStatus.checkedIn:
        visit.checkOut(_world.now());
      case VisitPlanStatus.completed:
        break; // A retry after a lost answer: the closed visit again.
      default:
        throw _conflict();
    }
  }

  @override
  Future<({VisitPlan plan, bool created})> startAdHoc(
      String visitId, AdHocPlanOutlet outlet) async {
    await MockLatency.tick();
    if (_world.find(visitId) case final known?
        when _adHocIds.contains(visitId)) {
      return (plan: known.toEntity(), created: false);
    }
    final depot = _world.depotByCode(outlet.depotCode) ??
        (throw MockVisitWorld.refusal(
            'PLAN_OUTLET_NOT_FOUND', 404, 'No depot has this code.'));
    final today = _world.today;
    final existing = _world.visits
        .where((v) => v.day == today && v.depot.code == depot.code)
        .firstOrNull;
    if (existing != null) {
      throw MockVisitWorld.refusal(AdHocPlanStarts.alreadyVisitedCode, 409,
          'This depot is already on today\'s visits.',
          details: {'planId': existing.id});
    }
    _adHocIds.add(visitId);
    return (plan: _world.addAdHoc(visitId, depot).toEntity(), created: true);
  }

  /// The overview the server would send for [period], counted from the
  /// visits in it.
  VisitPlansOverview _overview(PlanPeriod period) {
    final visits = _world.visitsIn(period);
    final (from, to) = _world.window(period);
    int count(VisitPlanStatus s) => visits.where((v) => v.status == s).length;
    return VisitPlansOverview(
      period: period.apiValue,
      from: from,
      to: to,
      total: visits.length,
      completed: count(VisitPlanStatus.completed),
      remaining: count(VisitPlanStatus.planned) +
          count(VisitPlanStatus.draft) +
          count(VisitPlanStatus.checkedIn),
      skipped: count(VisitPlanStatus.skipped),
      missed: count(VisitPlanStatus.missed),
      adHoc: visits.where((v) => v.adHoc).length,
      items: [for (final v in visits) v.toEntity()],
    );
  }

  /// The visit [planId], refused unless it is on today: only today's visits
  /// start, skip or check in.
  MockVisitRecord _todayVisit(String planId) {
    final visit = _world.require(planId);
    if (visit.day != _world.today) {
      throw MockVisitWorld.refusal(
          'PLAN_NOT_TODAY', 409, 'Only today\'s visits can be worked.');
    }
    return visit;
  }

  static ApiException _conflict() => MockVisitWorld.refusal(
      'PLAN_STATUS_CONFLICT', 409, 'This visit has moved on already.');
}
