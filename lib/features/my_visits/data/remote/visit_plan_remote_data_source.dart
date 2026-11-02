import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// The caller's own visit plans. Both endpoints answer the same `MyPlansView`.
///
/// Every method throws `ApiException` on any refusal or transport failure, and
/// `ServerException` on a 200 whose body cannot be read.
abstract interface class VisitPlanRemoteDataSource {
  /// `GET /api/v1/mobile/plans?period=` — the calendar's source.
  Future<VisitPlansOverview> fetchMyPlans(PlanPeriod period);

  /// `GET /api/v1/mobile/plans/today` — the Visits list's source.
  Future<VisitPlansOverview> fetchTodayPlans();

  /// `POST /api/v1/mobile/plans/{id}/skip` with `{ "reason": … }`.
  Future<void> skipPlan(String planId, String reason);

  /// `GET /api/v1/mobile/plans/{id}`.
  Future<PlanCheckInTarget> fetchCheckInTarget(String planId);

  /// `POST /api/v1/mobile/plans/{id}/check-in` as `multipart/form-data`.
  Future<PlanCheckInResult> checkIn(PlanCheckInRequest request);

  /// `POST /api/v1/mobile/plans/{id}/inventory-check-photo-upload` as
  /// `multipart/form-data`.
  Future<void> uploadInventoryPhotos(PlanInventoryUploadRequest request);

  /// `POST /api/v1/mobile/plans/{id}/check-out` as JSON.
  Future<void> checkOut(PlanCheckOutRequest request);

  /// `POST /api/v1/mobile/plans/ad-hoc` — the Draft visit, and whether it was
  /// made now (201) or already existed for [visitId] (200).
  Future<({VisitPlan plan, bool created})> startAdHoc(
      String visitId, AdHocPlanOutlet outlet);
}
