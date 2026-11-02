import 'dart:async';

import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/plan_inventory_log.dart';
import 'package:steelforce/features/my_visits/data/local/visit_plan_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/ad_hoc_plan_starts.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_refusal_messages.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_visit_steps.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

part 'visit_plan_failures.dart';
part 'visit_plan_read_through.dart';

/// The rep's plans: the server's answer when it can be reached, and the
/// device's copy of its last answer when it cannot (ADR-002).
///
/// Every successful read replaces the copy. Offline, a copy is used only while
/// it still describes the period asked for — today's plan saved yesterday is
/// not today's plan, so it is refused rather than shown as if it were.
class VisitPlanRepositoryImpl implements VisitPlanRepository {
  VisitPlanRepositoryImpl({
    required VisitPlanRemoteDataSource remote,
    required NetworkInfo network,
    VisitPlanLocalDataSource? local,
    PlanVisitSteps? steps,
    PlanInventoryLog? inventory,
    DateTime Function() now = DateTime.now,
  })  : _remote = remote,
        _inventory = inventory,
        _network = network,
        _local = local,
        _steps = steps,
        _now = now;

  final VisitPlanRemoteDataSource _remote;
  final NetworkInfo _network;
  final VisitPlanLocalDataSource? _local;

  /// The offline side of check-in, photos and check-out. Null keeps every
  /// step online-only.
  final PlanVisitSteps? _steps;

  /// Which visits have their photos. Null: none are known to.
  final PlanInventoryLog? _inventory;
  final DateTime Function() _now;
  final AdHocPlanStarts _adHocStarts = AdHocPlanStarts();

  @override
  ResultFuture<VisitPlansOverview> getMyPlans(PlanPeriod period) =>
      _worked(_readThrough(
        VisitPlanCacheKeys.period(period),
        () => _remote.fetchMyPlans(period),
        // The calendar asks for this month; a copy from last month is not it.
        stillValid: (at, now) => at.year == now.year && at.month == now.month,
      ));

  @override
  ResultFuture<VisitPlansOverview> getTodayPlans() async {
    final result = await _readThrough(
      VisitPlanCacheKeys.today,
      _remote.fetchTodayPlans,
      stillValid: (at, now) =>
          at.year == now.year && at.month == now.month && at.day == now.day,
    );
    // Today's visits, made ready to check in to offline later.
    if (result case Success(:final data)) {
      unawaited(_steps?.keepTargets(data.items));
    }
    return _worked(Future.value(result));
  }

  /// The answer with the steps this device still holds laid over it.
  ResultFuture<VisitPlansOverview> _worked(
      ResultFuture<VisitPlansOverview> read) async {
    final result = await read;
    final steps = _steps;
    if (steps == null) return result;
    return switch (result) {
      Success(:final data) => Success(await steps.overlay(data)),
      Failed() => result,
    };
  }

  @override
  ResultFuture<void> skipPlan(String planId, String reason) =>
      _guard(() => _remote.skipPlan(planId, reason), skipping: true);

  @override
  ResultFuture<PlanCheckInTarget> getCheckInTarget(String planId) {
    ResultFuture<PlanCheckInTarget> live() =>
        _guard(() => _remote.fetchCheckInTarget(planId));
    return _steps?.target(planId, live) ?? live();
  }

  @override
  ResultFuture<PlanCheckInResult> checkIn(PlanCheckInRequest request) {
    ResultFuture<PlanCheckInResult> live() =>
        _guard(() => _remote.checkIn(request),
            messageFor: PlanRefusalMessages.checkIn);
    return _steps?.deliver(request,
            live: live,
            sent: PlanCheckInResult(checkInId: request.checkInId, zone: ''),
            queued: PlanCheckInResult.queued(request.checkInId)) ??
        live();
  }

  @override
  ResultFuture<PlanStepDelivery> uploadInventoryPhotos(
      PlanInventoryUploadRequest request) {
    ResultFuture<PlanStepDelivery> send() => _step(
        request,
        () => _remote.uploadInventoryPhotos(request),
        PlanRefusalMessages.inventoryUpload);
    return _inventory?.track(request.planId, send) ?? send();
  }

  @override
  Future<bool> isInventoryDone(String planId) async =>
      await _inventory?.isDone(planId) ?? false;

  @override
  ResultFuture<PlanStepDelivery> checkOut(PlanCheckOutRequest request) => _step(
      request, () => _remote.checkOut(request), PlanRefusalMessages.checkOut);

  ResultFuture<PlanStepDelivery> _step(Object request,
      Future<void> Function() send, String Function(ApiError) messageFor) {
    ResultFuture<PlanStepDelivery> live() => _guard(() async {
          await send();
          return PlanStepDelivery.sent;
        }, messageFor: messageFor);
    return _steps?.deliver(request,
            live: live,
            sent: PlanStepDelivery.sent,
            queued: PlanStepDelivery.queued) ??
        live();
  }

  @override
  ResultFuture<void> resendPlanSteps(String planId) async {
    await _steps?.resend(planId);
    return const Success(null);
  }

  @override
  ResultFuture<void> discardPlanSteps(String planId) async {
    await _steps?.discard(planId);
    return const Success(null);
  }

  @override
  ResultFuture<AdHocPlanOutcome> startAdHoc(AdHocPlanOutlet outlet) =>
      _guard(() => _adHocStarts.send(_remote, outlet),
          messageFor: AdHocPlanStarts.messageFor);

  ResultFuture<T> _guard<T>(Future<T> Function() request,
      {bool skipping = false,
      String Function(ApiError error)? messageFor}) async {
    // Real reachability (ADR-005): failing here is faster and more honest than
    // waiting out a socket timeout.
    if (!await _network.isConnected) return const Failed(NetworkFailure());

    try {
      return Success(await request());
    } on ApiException catch (e) {
      return Failed(_planFailure(e.error,
          messageFor:
              messageFor ?? (skipping ? PlanRefusalMessages.skip : null)));
    } on ServerException {
      return const Failed(
          ServerFailure(message: 'my_visits.plans.error.unreadable'));
    }
  }
}
