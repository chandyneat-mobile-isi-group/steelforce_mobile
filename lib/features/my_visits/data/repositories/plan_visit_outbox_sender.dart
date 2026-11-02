import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_store.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_refusal_messages.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';

/// Sends plan visit steps saved offline, each visit's strictly in order —
/// the server takes photos only after the check-in, and the check-out only
/// after a photo.
///
/// A step that may simply not have got through (no network, a timeout, 429,
/// a 5xx) stays queued and stops its visit for now. Any other refusal is
/// flagged with what to tell the rep, and holds the steps behind it until
/// the rep resends or discards — nothing captured is thrown away. Every step
/// is sent with its own id, so a resend after a lost answer is the same
/// request, not a second one.
class PlanVisitOutboxSender {
  PlanVisitOutboxSender({
    required VisitPlanRemoteDataSource remote,
    required PlanVisitOutboxStore store,
    AppLogger? logger,
  })  : _remote = remote,
        _store = store,
        _logger = logger;

  final VisitPlanRemoteDataSource _remote;
  final PlanVisitOutboxStore _store;
  final AppLogger? _logger;

  /// One drain at a time: the sync engine and a live step may both ask.
  Future<void> _lock = Future.value();

  /// Every visit with steps waiting, the oldest visit first.
  Future<void> sendAll() => _locked(() async {
        final planIds = <String>{
          for (final step in await _store.all()) step.planId,
        };
        for (final planId in planIds) {
          await _sendPlan(planId);
        }
      });

  /// [planId]'s waiting steps only.
  Future<void> sendPlan(String planId) => _locked(() => _sendPlan(planId));

  Future<void> _locked(Future<void> Function() run) {
    final next = _lock.then((_) => run());
    _lock = next.catchError((_) {});
    return next;
  }

  Future<void> _sendPlan(String planId) async {
    for (final step in await _store.stepsFor(planId)) {
      if (step.needsAttention) return;
      if (!await _send(step)) return;
    }
  }

  /// True when [step] is done with and the next one may go.
  Future<bool> _send(PlanOutboxStep step) async {
    try {
      await switch (step.request) {
        PlanCheckInRequest r => _remote.checkIn(r),
        PlanInventoryUploadRequest r => _remote.uploadInventoryPhotos(r),
        PlanCheckOutRequest r => _remote.checkOut(r),
        _ => Future<void>.value(),
      };
      await _sent(step);
      return true;
    } on ApiException catch (e) {
      final error = e.error;
      final code = error.serverCode ?? error.code;
      // The visit already holds the most photos it can: what check-out needs.
      if (step.kind == PlanStepKind.inventory &&
          code == planInventoryPhotoLimitCode) {
        await _sent(step);
        return true;
      }
      if (mayStillLand(error)) {
        await _store.markAttempted(step.id, code);
        _log('retry', step, code);
        return false;
      }
      await _store.flag(step.id, code, messageFor(step.kind, error));
      _log('held', step, code);
      return false;
    } on ServerException {
      // A 2xx we could not read: it may well have landed, and the same id
      // makes asking again safe.
      await _store.markAttempted(step.id, ApiErrorCodes.unknown);
      _log('retry', step, ApiErrorCodes.unknown);
      return false;
    }
  }

  Future<void> _sent(PlanOutboxStep step) async {
    await _store.remove(step);
    _log('sent', step, null);
  }

  /// No answer, or one that says "not now" rather than "no".
  static bool mayStillLand(ApiError error) {
    final status = error.statusCode;
    return status == null ||
        status == 401 ||
        status == 408 ||
        status == 429 ||
        status >= 500;
  }

  /// The key the rep is shown for a step held on [error].
  static String messageFor(PlanStepKind kind, ApiError error) {
    if (error.statusCode == 403) return 'my_visits.plans.error.forbidden';
    return switch (kind) {
      PlanStepKind.checkIn => PlanRefusalMessages.checkIn(error),
      PlanStepKind.inventory => PlanRefusalMessages.inventoryUpload(error),
      PlanStepKind.checkOut => PlanRefusalMessages.checkOut(error),
    };
  }

  void _log(String outcome, PlanOutboxStep step, String? code) =>
      _logger?.info('visits.planOutbox.$outcome', fields: {
        'kind': step.kind.name,
        'planId': step.planId,
        'stepId': step.id,
        if (code != null) 'errorCode': code,
      });
}
