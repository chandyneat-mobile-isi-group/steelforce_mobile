import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// The rep's visit plans. The rep is identified by the access token alone —
/// nothing here takes a territory or employee code.
abstract interface class VisitPlanRepository {
  /// `GET /api/v1/mobile/plans` — every plan in [period], for the calendar.
  ResultFuture<VisitPlansOverview> getMyPlans(PlanPeriod period);

  /// `GET /api/v1/mobile/plans/today` — today's plans, for the Visits list.
  ResultFuture<VisitPlansOverview> getTodayPlans();

  /// `POST /api/v1/mobile/plans/{id}/skip` — skips the plan [planId] with
  /// [reason]. Online only: the server checks the date and status.
  ResultFuture<void> skipPlan(String planId, String reason);

  /// `GET /api/v1/mobile/plans/{id}` — the depot's location and radius,
  /// read before a check-in.
  ResultFuture<PlanCheckInTarget> getCheckInTarget(String planId);

  /// `POST /api/v1/mobile/plans/{id}/check-in` — multipart; saved on the
  /// device and sent later when it cannot go now
  /// ([PlanCheckInResult.queued]).
  ResultFuture<PlanCheckInResult> checkIn(PlanCheckInRequest request);

  /// `POST /api/v1/mobile/plans/{id}/inventory-check-photo-upload` —
  /// multipart. Adds the photos to a checked-in visit; saved on the device
  /// and sent later when it cannot go now.
  ResultFuture<PlanStepDelivery> uploadInventoryPhotos(
      PlanInventoryUploadRequest request);

  /// `POST /api/v1/mobile/plans/{id}/check-out`. Closes a checked-in visit
  /// that has at least one inventory photo; saved on the device and sent
  /// later when it cannot go now.
  ResultFuture<PlanStepDelivery> checkOut(PlanCheckOutRequest request);

  /// Whether [planId]'s inventory photos were sent or saved to send — the
  /// condition for offering Check out. Never fails: unknown is false.
  Future<bool> isInventoryDone(String planId);

  /// Sends [planId]'s steps the server refused again, once the rep has seen
  /// why.
  ResultFuture<void> resendPlanSteps(String planId);

  /// Drops [planId]'s steps still on the device — the rep's call, after a
  /// refusal they cannot fix.
  ResultFuture<void> discardPlanSteps(String planId);

  /// `POST /api/v1/mobile/plans/ad-hoc` — online only. A retry for the same
  /// outlet sends the same visit id until the server gives a final answer.
  ResultFuture<AdHocPlanOutcome> startAdHoc(AdHocPlanOutlet outlet);
}
