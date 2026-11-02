import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/plan_visit_outbox_store.dart';
import 'package:steelforce/features/my_visits/data/local/visit_plan_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/plan_visit_outbox_sender.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// The offline side of a plan visit: check-in, inventory photos and
/// check-out are saved on the device when they cannot go now, and sent in
/// order later (ADR-002 — the write succeeds locally first).
///
/// A step goes live only when the device is online **and** its visit has
/// nothing waiting; otherwise it queues behind what is there, so the server
/// never gets a check-out before the check-in it follows.
class PlanVisitSteps {
  PlanVisitSteps({
    required PlanVisitOutboxStore store,
    required PlanVisitOutboxSender sender,
    required NetworkInfo network,
    required VisitPlanRemoteDataSource remote,
    required VisitPlanLocalDataSource local,
    void Function()? onQueued,
    DateTime Function() now = DateTime.now,
  })  : _store = store,
        _sender = sender,
        _network = network,
        _remote = remote,
        _local = local,
        _onQueued = onQueued,
        _now = now;

  final PlanVisitOutboxStore _store;
  final PlanVisitOutboxSender _sender;
  final NetworkInfo _network;
  final VisitPlanRemoteDataSource _remote;
  final VisitPlanLocalDataSource _local;
  final void Function()? _onQueued;
  final DateTime Function() _now;

  /// Sends [request] live through [live], or saves it. [sent] and [queued]
  /// are what the caller gets back for each.
  Future<Result<T>> deliver<T>(
    Object request, {
    required ResultFuture<T> Function() live,
    required T sent,
    required T queued,
  }) async {
    final planId = PlanOutboxCodec.planIdOf(request);
    final waiting = (await _store.stepsFor(planId)).isNotEmpty;
    final online = await _network.isConnected;
    if (online && !waiting) {
      final result = await live();
      if (result case Failed(:final failure) when !_noAnswer(failure)) {
        return result;
      }
      if (result is Success<T>) return result;
    }
    await _store.enqueue(request);
    if (!online) {
      _onQueued?.call();
      return Success(queued);
    }
    // Online with steps ahead of it: send the visit now, in order.
    await _sender.sendPlan(planId);
    final id = PlanOutboxCodec.idOf(request);
    final mine =
        (await _store.stepsFor(planId)).where((s) => s.id == id).firstOrNull;
    if (mine == null) return Success(sent);
    if (mine.needsAttention) {
      return Failed(ServerFailure(
        message: mine.errorMessage ?? 'my_visits.plans.sync.held',
        code: mine.errorCode,
      ));
    }
    _onQueued?.call();
    return Success(queued);
  }

  /// [live] when it answers; offline, the kept copy, else what today's plan
  /// says about the depot — with no radius, so the server judges the zone.
  ResultFuture<PlanCheckInTarget> target(
      String planId, ResultFuture<PlanCheckInTarget> Function() live) async {
    final result = await live();
    switch (result) {
      case Success(:final data):
        await _keep(data);
        return result;
      case Failed(:final failure) when _noAnswer(failure):
        final kept = await _local.readTarget(planId);
        if (kept != null) return Success(kept.target);
        final plan = (await _local.read(VisitPlanCacheKeys.today))
            ?.items
            .where((p) => p.id == planId)
            .firstOrNull;
        if (plan == null) return result;
        return Success(PlanCheckInTarget(
          planId: plan.id,
          status: plan.status,
          depotCode: plan.depotCode,
          depotName: plan.displayName,
          depotLatitude: plan.latitude,
          depotLongitude: plan.longitude,
        ));
      case Failed():
        return result;
    }
  }

  /// Fetches the depot location and radius of today's startable visits not
  /// kept since today began, so they can be checked in to offline. Best
  /// effort: a failure leaves the visit to the fallback in [target].
  Future<void> keepTargets(List<VisitPlan> plans) async {
    if (!await _network.isConnected) return;
    final today = _now();
    for (final plan in plans.where((p) => p.canStart)) {
      final kept = await _local.readTarget(plan.id);
      final at = kept?.fetchedAt;
      if (at != null &&
          at.year == today.year &&
          at.month == today.month &&
          at.day == today.day) {
        continue;
      }
      try {
        await _keep(await _remote.fetchCheckInTarget(plan.id));
      } on Object {
        return; // Offline or refused: the next list load tries again.
      }
    }
  }

  /// [overview]'s plans as this device has worked them: a check-in saved
  /// offline reads CheckedIn, a check-out Completed, each with its sync
  /// state — until the server says the same.
  Future<VisitPlansOverview> overlay(VisitPlansOverview overview) async {
    final steps = await _store.all();
    if (steps.isEmpty) return overview;
    final byPlan = <String, List<PlanOutboxStep>>{};
    for (final step in steps) {
      byPlan.putIfAbsent(step.planId, () => []).add(step);
    }
    return overview.withItems([
      for (final plan in overview.items)
        if (byPlan[plan.id] case final mine?) _worked(plan, mine) else plan,
    ]);
  }

  static VisitPlan _worked(VisitPlan plan, List<PlanOutboxStep> steps) {
    final held = steps.where((s) => s.needsAttention).firstOrNull;
    final kinds = steps.map((s) => s.kind).toSet();
    final open = plan.status == VisitPlanStatus.planned ||
        plan.status == VisitPlanStatus.draft ||
        plan.status == VisitPlanStatus.checkedIn;
    return plan.withLocalSync(
      status: !open
          ? plan.status
          : kinds.contains(PlanStepKind.checkOut)
              ? VisitPlanStatus.completed
              : VisitPlanStatus.checkedIn,
      syncState:
          held == null ? PlanSyncState.pending : PlanSyncState.needsAttention,
      syncMessage: held?.errorMessage,
    );
  }

  /// The rep asked to send [planId]'s held steps again.
  Future<void> resend(String planId) async {
    await _store.clearFlags(planId);
    if (await _network.isConnected) {
      await _sender.sendPlan(planId);
    } else {
      _onQueued?.call();
    }
  }

  Future<void> discard(String planId) => _store.discardPlan(planId);

  Future<void> _keep(PlanCheckInTarget target) async {
    try {
      await _local.saveTarget(target, _now());
    } on Object {
      // A convenience for later; never worth failing the answer in hand.
    }
  }

  /// No answer reached the app — offline, unreachable, timed out.
  static bool _noAnswer(Failure failure) =>
      failure is NetworkFailure ||
      failure is ServerUnreachableFailure ||
      (failure is ServerFailure && failure.statusCode == null);
}
