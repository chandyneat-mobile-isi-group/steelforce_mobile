import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';

/// The plans refusals the contract names, as localisation keys.
abstract final class PlanRefusalMessages {
  /// The skip refusals the contract names, each as something the rep can act
  /// on. Matched by the server's code — `serverCode` for a wrapped `error`
  /// body, `code` for a problem document — falling back to the HTTP status.
  static String skip(ApiError error) =>
      switch ((error.serverCode ?? error.code, error.statusCode)) {
        ('PLAN_NOT_TODAY', _) => 'my_visits.plans.skip.error.not_today',
        ('PLAN_STATUS_CONFLICT', _) => 'my_visits.plans.skip.error.conflict',
        ('PLAN_NOT_FOUND', _) ||
        (_, 404) =>
          'my_visits.plans.skip.error.not_found',
        ('VALIDATION_FAILED', _) ||
        (_, 400) =>
          'my_visits.plans.skip.error.invalid_reason',
        _ => 'my_visits.plans.skip.error.failed',
      };

  /// The check-in refusals the contract names. `PLAN_CHECK_IN_REASON_REQUIRED`
  /// keeps its code on the failure: the screen answers it by asking for a
  /// reason, not by showing an error.
  static String checkIn(ApiError error) =>
      switch ((error.serverCode ?? error.code, error.statusCode)) {
        (planCheckInReasonRequiredCode, _) =>
          'my_visits.plans.check_in.error.reason',
        ('PLAN_NOT_TODAY', _) => 'my_visits.plans.check_in.error.not_today',
        ('PLAN_STATUS_CONFLICT', _) =>
          'my_visits.plans.check_in.error.conflict',
        ('PLAN_NOT_FOUND', _) ||
        (_, 404) =>
          'my_visits.plans.check_in.error.not_found',
        ('PLAN_CHECK_IN_POSITION_INVALID', _) =>
          'my_visits.plans.check_in.error.no_fix',
        ('PLAN_CHECK_IN_PHOTO_INVALID', _) ||
        ('PLAN_CHECK_IN_PHOTO_TOO_LARGE', _) ||
        (_, 413) =>
          'my_visits.plans.check_in.error.photo',
        ('TOO_MANY_REQUESTS', _) ||
        (_, 429) =>
          'my_visits.plans.check_in.error.busy',
        ('VALIDATION_FAILED', _) ||
        (_, 400) =>
          'my_visits.plans.check_in.error.invalid',
        // Recoverable: the same check-in id makes a retry safe.
        (_, final int status) when status >= 500 =>
          'my_visits.plans.check_in.error.server',
        _ => 'my_visits.plans.check_in.error.failed',
      };

  /// The stock-photo upload refusals the contract names.
  /// `PLAN_INVENTORY_PHOTO_LIMIT` keeps its code on the failure: the visit
  /// already has its photos, so the flow moves on to check-out.
  static String inventoryUpload(ApiError error) =>
      switch ((error.serverCode ?? error.code, error.statusCode)) {
        (planInventoryPhotoLimitCode, _) =>
          'my_visits.plans.inventory.error.full',
        ('PLAN_STATUS_CONFLICT', _) =>
          'my_visits.plans.inventory.error.conflict',
        ('CONCURRENCY_CONFLICT', _) => 'my_visits.plans.inventory.error.again',
        ('PLAN_NOT_FOUND', _) ||
        (_, 404) =>
          'my_visits.plans.check_in.error.not_found',
        ('PLAN_INVENTORY_PHOTO_INVALID', _) ||
        ('PLAN_INVENTORY_PHOTO_TOO_LARGE', _) ||
        (_, 413) =>
          'my_visits.plans.check_in.error.photo',
        ('TOO_MANY_REQUESTS', _) ||
        (_, 429) =>
          'my_visits.plans.inventory.error.busy',
        (_, final int status) when status >= 500 =>
          'my_visits.plans.inventory.error.server',
        _ => 'my_visits.plans.inventory.error.failed',
      };

  /// The check-out refusals the contract names.
  static String checkOut(ApiError error) =>
      switch ((error.serverCode ?? error.code, error.statusCode)) {
        ('PLAN_INVENTORY_PHOTO_REQUIRED', _) =>
          'my_visits.plans.check_out.error.photo_required',
        ('PLAN_STATUS_CONFLICT', _) =>
          'my_visits.plans.check_out.error.conflict',
        ('PLAN_NOT_FOUND', _) ||
        (_, 404) =>
          'my_visits.plans.check_in.error.not_found',
        ('TOO_MANY_REQUESTS', _) ||
        (_, 429) =>
          'my_visits.plans.check_out.error.busy',
        ('VALIDATION_FAILED', _) ||
        (_, 400) =>
          'my_visits.plans.check_out.error.invalid',
        // Recoverable: the same check-out id makes a retry safe.
        (_, final int status) when status >= 500 =>
          'my_visits.plans.check_out.error.server',
        _ => 'my_visits.plans.check_out.error.failed',
      };
}
