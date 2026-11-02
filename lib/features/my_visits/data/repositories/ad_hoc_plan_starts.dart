import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';

/// The ad hoc starts not yet answered for good, one visit id per outlet.
///
/// The contract has the app choose `visitId` and keep it for retries: the
/// same id again returns the same visit (200), a new one could make a second.
/// So the id is kept while the answer may not have landed — no network, a
/// timeout, 429, a 5xx, an unreadable 200 — and dropped once the server has
/// said yes or a final no.
class AdHocPlanStarts {
  final Map<String, String> _visitIds = {};

  static const alreadyVisitedCode = 'PLAN_ALREADY_VISITED_TODAY';

  /// The visit id the next start at [outlet] sends.
  String visitIdFor(AdHocPlanOutlet outlet) =>
      _visitIds.putIfAbsent(outlet.key, Uuid.v4);

  /// One attempt. Throws what [remote] throws unless the answer is
  /// [alreadyVisitedCode], which is an outcome, not a refusal.
  Future<AdHocPlanOutcome> send(
      VisitPlanRemoteDataSource remote, AdHocPlanOutlet outlet) async {
    final visitId = visitIdFor(outlet);
    try {
      final answer = await remote.startAdHoc(visitId, outlet);
      _visitIds.remove(outlet.key);
      return AdHocPlanStarted(plan: answer.plan, created: answer.created);
    } on ApiException catch (e) {
      final error = e.error;
      if (!_mayHaveLanded(error)) _visitIds.remove(outlet.key);
      if (codeOf(error) == alreadyVisitedCode) {
        return AdHocPlanAlreadyToday(planId: _string(error.details?['planId']));
      }
      rethrow;
    }
  }

  /// The server's code: `serverCode` for a wrapped `error` body, `code` for a
  /// problem document.
  static String codeOf(ApiError error) => error.serverCode ?? error.code;

  static bool _mayHaveLanded(ApiError error) {
    final status = error.statusCode;
    return status == null || status == 408 || status == 429 || status >= 500;
  }

  /// The refusals the contract names, as keys the rep can act on. 403
  /// (`PLAN_EMPLOYEE_CODE_REQUIRED`) never reaches here: every plans call
  /// reads it as "only for sales employees".
  static String messageFor(ApiError error) =>
      switch ((codeOf(error), error.statusCode)) {
        ('PLAN_OUTLET_NOT_FOUND', _) ||
        (_, 404) =>
          'my_visits.plans.ad_hoc.error.not_found',
        ('PLAN_AD_HOC_LIMIT_REACHED', _) =>
          'my_visits.plans.ad_hoc.error.limit',
        // A clash with another visit's id: the id is dropped, so the next
        // tap sends a new one.
        ('PLAN_ID_IN_USE', _) => 'my_visits.plans.ad_hoc.error.retry',
        ('TOO_MANY_REQUESTS', _) ||
        (_, 429) =>
          'my_visits.plans.ad_hoc.error.busy',
        ('VALIDATION_FAILED', _) ||
        (_, 400) =>
          'my_visits.plans.ad_hoc.error.invalid',
        (_, final int status) when status >= 500 =>
          'my_visits.plans.ad_hoc.error.server',
        _ => 'my_visits.plans.ad_hoc.error.failed',
      };

  static String? _string(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
