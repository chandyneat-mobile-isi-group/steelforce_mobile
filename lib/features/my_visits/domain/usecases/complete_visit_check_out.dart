import 'dart:math';

import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_location_samples.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';

/// Completes the deferred check-out for the rep's active visit and clears the
/// navigation state — the counterpart to the guided flow no longer checking
/// out at the end of the stock count (the stop stays "Checked In" through the
/// Quotation/Sales Order task).
///
/// Works purely off the persisted [ActiveWorkflow] row (route + stop) so it can
/// be triggered from *anywhere* — the Order feature's submit handler or an
/// explicit "Check out" control on the Continue-Working card — without a live
/// [ActiveRouteBloc] reference (that bloc is out of scope over there).
///
/// Idempotent: an already-checked-out (or vanished) stop just clears the
/// pointer and reports success, so a double-tap or a race with the bloc's own
/// check-out can't create a second `checkouts` row. Returns `true` when a visit
/// was actually completed/cleared.
///
/// [CheckOutChoice] is how the visit ended — with an order (and which) or
/// without (and why), as the rep picked on the check-out sheet. Null only for
/// a caller that predates outcomes; the server stores that as `unknown`.
///
/// Saved on the device first, always. Then, when [_sendCheckOut] is wired,
/// offered to the server straight away (`POST /visits/check-outs`); offline
/// it waits for the next sync.
class CompleteVisitCheckOut extends UseCase<bool, CheckOutChoice?> {
  const CompleteVisitCheckOut(
    this._workflowRepository,
    this._routeRepository,
    this._checkOut,
    this._updateStopStatus, [
    this._logger,
    this._fetchLocationSamples,
    this._visits,
    this._sendCheckOut,
  ]);

  /// Finds the check-in this check-out closes. Optional for the same reason
  /// as the two above; without it `checkInId` is left out and the server
  /// closes the stop's open visit.
  final VisitRepository? _visits;

  /// Optional: without it the check-out waits for the batch push.
  final SendCheckOut? _sendCheckOut;

  final ActiveWorkflowRepository _workflowRepository;
  final RouteRepository _routeRepository;
  final CheckOut _checkOut;
  final UpdateStopStatus _updateStopStatus;

  /// The route's recorded GPS trail, used only for its newest sample.
  ///
  /// Optional because this use case is constructed positionally in DI and in
  /// tests, and because a check-out must never fail for want of a position.
  /// **Register it** (`my_visits_injection.dart`) or every check-out keeps
  /// falling back to the shop's own pin — see [_recordFor].
  final FetchLocationSamples? _fetchLocationSamples;

  /// Optional so existing tests construct this unchanged.
  ///
  /// Every branch below that declines to write is logged. All three look
  /// identical from the outside — the rep taps "Complete Visit", the screen
  /// closes, and nothing happens: no check-out row, so the push finds an empty
  /// queue and makes no request, and no status write, so the outlet still reads
  /// as not visited. Without a line saying *which* precondition was missing,
  /// that is indistinguishable from a broken button.
  final AppLogger? _logger;

  @override
  ResultFuture<bool> call(CheckOutChoice? params) async {
    final workflowResult = await _workflowRepository.getActiveWorkflow();
    final workflow =
        workflowResult.when(success: (w) => w, failure: (_) => null);
    final stopId = workflow?.currentStopId;
    if (workflow == null || stopId == null) {
      _logger?.warning('visit.checkout.skipped', fields: {
        'reason': workflow == null ? 'noActiveWorkflow' : 'noCurrentStopId',
        'routeId': workflow?.routeId,
      });
      return _clearAndReturn(false);
    }

    final routeResult = await _routeRepository.getRoute(workflow.routeId);
    final route = routeResult.when(success: (r) => r, failure: (_) => null);
    RouteStop? stop;
    if (route != null) {
      for (final s in route.stops) {
        if (s.id == stopId) {
          stop = s;
          break;
        }
      }
    }
    if (stop == null) {
      _logger?.warning('visit.checkout.skipped', fields: {
        'reason': route == null ? 'routeNotFound' : 'stopNotOnRoute',
        'routeId': workflow.routeId,
        'stopId': stopId,
      });
      return _clearAndReturn(true);
    }

    // Already resolved — nothing to write, just drop the pointer (idempotent).
    if (stop.status != VisitStatus.checkedIn) {
      // The one worth reading twice in a bug report: a stop still `pending` or
      // `arrived` means check-in never completed, so there is nothing to close.
      _logger?.warning('visit.checkout.skipped', fields: {
        'reason': 'stopNotCheckedIn',
        'stopId': stopId,
        'status': stop.status.name,
      });
      return _clearAndReturn(true);
    }

    final now = DateTime.now();
    final position = await _lastKnownPosition(workflow.routeId);
    if (position == null) {
      _logger?.warning('visit.checkout.position_unavailable', fields: {
        'stopId': stop.id,
        'routeId': workflow.routeId,
        'reason': _fetchLocationSamples == null ? 'notWired' : 'noSamples',
      });
    }
    final checkInId = await _checkInIdFor(stop.id);
    final record = _recordFor(stop, now, position, params, checkInId);
    final checkOutResult = await _checkOut(record);
    if (checkOutResult is Failed<CheckOutRecord>) {
      return Failed(checkOutResult.failure);
    }
    await _updateStopStatus(UpdateStopStatusParams(
        stopId: stop.id, status: VisitStatus.checkedOut, actualDeparture: now));
    // After the local status is written, so a route pull that lands while
    // this is in flight cannot revert the stop. The visit is closed whatever
    // the answer: offline or refused, it is queued or dropped by the
    // repository, never re-opened.
    final send = _sendCheckOut;
    if (send != null) await send(record);
    _logger?.info('visit.checkout.completed',
        fields: {'stopId': stop.id, 'routeId': workflow.routeId});
    return _clearAndReturn(true);
  }

  /// The newest GPS sample recorded on this route, or null.
  ///
  /// `LocationTrackingCubit` writes these continuously while a route runs, so
  /// on any real visit there is one. Null means either the dependency is
  /// unregistered or tracking never started — both worth a log line, neither
  /// worth refusing a check-out over.
  Future<({double latitude, double longitude})?> _lastKnownPosition(
      String routeId) async {
    final fetch = _fetchLocationSamples;
    if (fetch == null) return null;

    final result = await fetch(RouteIdParams(routeId));
    final samples = result.when(success: (s) => s, failure: (_) => null);
    if (samples == null || samples.isEmpty) return null;

    var newest = samples.first;
    for (final sample in samples) {
      if (sample.timestamp.isAfter(newest.timestamp)) newest = sample;
    }
    return (latitude: newest.latitude, longitude: newest.longitude);
  }

  /// **Where the rep was, not where the shop is.**
  ///
  /// These coordinates used to be `stop.depot.latitude/longitude`
  /// unconditionally — the shop's own pin, recorded as the rep's position. A
  /// check-out written that way always reads as exactly on-location, so it is
  /// worthless as the location evidence api.md §8.2 treats it as.
  ///
  /// The depot pin remains the fallback when no sample exists, because a
  /// check-out that fails to write is worse than one written from a weaker
  /// source — but that case is logged rather than passed off as measured.
  Future<String?> _checkInIdFor(String stopId) async {
    final visits = _visits;
    if (visits == null) return null;
    return (await visits.checkInIdForStop(stopId))
        .when(success: (id) => id, failure: (_) => null);
  }

  CheckOutRecord _recordFor(
    RouteStop stop,
    DateTime now,
    ({double latitude, double longitude})? position,
    CheckOutChoice? choice,
    String? checkInId,
  ) =>
      CheckOutRecord(
        id: '${now.microsecondsSinceEpoch}-${Random().nextInt(99999)}',
        stopId: stop.id,
        timestamp: now,
        latitude: position?.latitude ?? stop.depot.latitude,
        longitude: position?.longitude ?? stop.depot.longitude,
        durationMinutes: stop.actualArrival == null
            ? 0
            : now.difference(stop.actualArrival!).inMinutes,
        visitSummary: 'Visit completed',
        checkInId: checkInId,
        outcome: choice?.outcome,
        orders: choice?.orders ?? const [],
        noOrderReason: choice?.noOrderReason,
        noOrderNote: choice?.noOrderNote,
      );

  Future<Result<bool>> _clearAndReturn(bool completed) async {
    await _workflowRepository.clearActiveWorkflow();
    return Success(completed);
  }
}
