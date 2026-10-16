import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/clear_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/domain/usecases/save_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_route_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route/check_in_decision.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route/check_in_record_builder.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route/check_in_submission.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route/workflow_pointer_writer.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/events/active_route_event.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';

const _policy = FraudPolicy();

/// The full-workday state machine: Start Day -> Navigate -> Arrive ->
/// Geofence Validation -> Check In -> Visit -> Check Out -> Next Stop ->
/// End Day. Mirrors `PipelineBloc`'s optimistic-update / single-current-
/// state shape used elsewhere in the app.
class ActiveRouteBloc extends Bloc<ActiveRouteEvent, ActiveRouteState> {
  ActiveRouteBloc({
    required GetRoute getRoute,
    required UpdateRouteStatus updateRouteStatus,
    required UpdateStopStatus updateStopStatus,
    required CheckIn checkIn,
    required CheckOut checkOut,
    required RecordFraudFlag recordFraudFlag,
    required FraudDetectionService fraudDetectionService,
    required SaveActiveWorkflow saveActiveWorkflow,
    required ClearActiveWorkflow clearActiveWorkflow,
    required GetActiveWorkflow getActiveWorkflow,
    SendCheckIn? sendCheckIn,
  })  : _sendCheckIn = sendCheckIn,
        _getRoute = getRoute,
        _updateRouteStatus = updateRouteStatus,
        _updateStopStatus = updateStopStatus,
        _checkIn = checkIn,
        _checkOut = checkOut,
        _recordFraudFlag = recordFraudFlag,
        _fraudDetectionService = fraudDetectionService,
        _saveActiveWorkflow = saveActiveWorkflow,
        _clearActiveWorkflow = clearActiveWorkflow,
        _getActiveWorkflow = getActiveWorkflow,
        super(const ActiveRouteLoading()) {
    on<ActiveRouteLoadRequested>(_onLoad);
    on<StartDayRequested>(_onStartDay, transformer: droppable());
    on<StopSelected>(_onStopSelected);
    on<GeofenceStatusChanged>(_onGeofenceChanged);
    on<CheckInRequested>(_onCheckIn, transformer: droppable());
    on<CheckOutRequested>(_onCheckOut, transformer: droppable());
    on<NextStopRequested>(_onNextStop, transformer: droppable());
    on<SkipStopRequested>(_onSkipStop, transformer: droppable());
    on<EndDayRequested>(_onEndDay, transformer: droppable());
  }

  final GetRoute _getRoute;

  /// Offers a saved check-in to the server straight away. Optional so the
  /// local-only construction sites (tests) still compile; without it the
  /// check-in waits for the batch push.
  final SendCheckIn? _sendCheckIn;
  final UpdateRouteStatus _updateRouteStatus;
  final UpdateStopStatus _updateStopStatus;
  final CheckIn _checkIn;
  final CheckOut _checkOut;
  final RecordFraudFlag _recordFraudFlag;
  final FraudDetectionService _fraudDetectionService;
  final SaveActiveWorkflow _saveActiveWorkflow;
  final ClearActiveWorkflow _clearActiveWorkflow;
  final GetActiveWorkflow _getActiveWorkflow;

  /// The "Continue Working" resume pointer; see [WorkflowPointerWriter].
  late final WorkflowPointerWriter _pointer = WorkflowPointerWriter(
    save: _saveActiveWorkflow,
    clear: _clearActiveWorkflow,
    get: _getActiveWorkflow,
  );

  void _persistWorkflow(ActiveRouteReady state) => _pointer.persist(state);

  late final CheckInSubmission _submission = CheckInSubmission(
    checkIn: _checkIn,
    updateStopStatus: _updateStopStatus,
    sendCheckIn: _sendCheckIn,
    onError: addError,
  );

  Future<void> _onLoad(
      ActiveRouteLoadRequested event, Emitter<ActiveRouteState> emit) async {
    emit(const ActiveRouteLoading());
    final result = await _getRoute(RouteIdParams(event.routeId));
    result.when(
      success: (route) => emit(ActiveRouteReady(
          route: route,
          // Read back from the route, not hardcoded `false`.
          //
          // `StartDayRequested` persists `RouteStatus.inProgress`, so the
          // route itself is the durable record of whether the day is running.
          // Assuming `false` here meant every reload of an already-running
          // route came back up believing the day had not started — and
          // `_persistWorkflow` is gated on that flag, so the resume pointer
          // was never written and the visit could not be closed.
          dayStarted: route.status == RouteStatus.inProgress ||
              route.status == RouteStatus.completed,
          currentStopIndex: -1)),
      failure: (f) => emit(ActiveRouteError(f.message)),
    );
  }

  Future<void> _onStartDay(
      StartDayRequested event, Emitter<ActiveRouteState> emit) async {
    final current = state;
    if (current is! ActiveRouteReady) return;
    await _updateRouteStatus(
        UpdateRouteStatusParams(current.route.id, RouteStatus.inProgress));

    // Re-read state instead of reusing the pre-await snapshot: StopSelected
    // and/or GeofenceStatusChanged (both processed concurrently, since
    // neither uses `droppable()`) can land while this update is in flight.
    // Emitting off the stale `current` would silently stomp on those
    // updates — e.g. reset a correctly-detected `insideGeofence: true` back
    // to false, leaving "I've Arrived" locked even while standing in the
    // geofence.
    final latest = state;
    if (latest is! ActiveRouteReady) return;
    final next = latest.copyWith(
      route: latest.route.copyWith(status: RouteStatus.inProgress),
      dayStarted: true,
      // Only default to the first stop if nothing has already selected one.
      currentStopIndex: latest.currentStopIndex >= 0
          ? latest.currentStopIndex
          : (latest.route.stops.isEmpty ? -1 : 0),
    );
    emit(next);
    _persistWorkflow(next);
  }

  void _onStopSelected(StopSelected event, Emitter<ActiveRouteState> emit) {
    final current = state;
    if (current is! ActiveRouteReady) return;
    final next = current.copyWith(
      currentStopIndex: event.index,
      insideGeofence: false,
      blockedCheckInReason: () => null,
      checkInWarnings: const [],
      checkInSaveFailed: false,
      checkInRefusal: () => null,
    );
    emit(next);
    _persistWorkflow(next);
  }

  void _onGeofenceChanged(
      GeofenceStatusChanged event, Emitter<ActiveRouteState> emit) {
    final current = state;
    // Deliberately **not** gated on `dayStarted`. It used to be, and that is
    // the same class of silent block this whole path suffered from: a rep who
    // reaches check-in without the day having been marked started gets no
    // geofence updates at all, so `insideGeofence` stays at the `false` that
    // `_onStopSelected` wrote and every check-in is refused with a reason the
    // rep cannot act on. Position evidence is harmless before the day starts.
    if (current is! ActiveRouteReady || !current.hasCurrentStop) {
      return;
    }
    emit(current.copyWith(
      insideGeofence: event.insideGeofence,
      distanceMeters: event.distanceMeters,
      accuracyMeters: event.accuracyMeters,
      isMocked: event.isMocked,
      repLatitude: event.latitude,
      repLongitude: event.longitude,
      depotLocationKnown: event.depotLocationKnown,
    ));
  }

  Future<void> _onCheckIn(
      CheckInRequested event, Emitter<ActiveRouteState> emit) async {
    final initial = state;
    // Not loaded at all: nothing to answer with. The screen's own watchdog
    // releases its spinner in that case.
    if (initial is! ActiveRouteReady) return;

    // Every exit below emits with this, so the screen always gets an answer —
    // see `ActiveRouteReady.checkInAttempt`.
    final attempt = initial.checkInAttempt + 1;

    // Check in the stop the screen asked for, not whichever index is current.
    var current = initial;
    final requestedId = event.stopId;
    if (requestedId != null) {
      final index = current.route.stops.indexWhere((s) => s.id == requestedId);
      if (index >= 0 && index != current.currentStopIndex) {
        current = current.copyWith(currentStopIndex: index);
      }
    }

    if (!current.hasCurrentStop) {
      emit(_answered(current, attempt,
          blockedReason:
              'No stop selected — go back and open the stop again.'));
      return;
    }
    final stop = current.route.stops[current.currentStopIndex];
    // Idempotency guard: a double-tap or a resume-triggered re-entry into
    // RouteCheckInScreen must not create a second `checkins` row for the
    // same stop (mirrors the existing guard in `_onCheckOut`). It used to
    // return *silently*, which left the screen's spinner running forever;
    // now it answers, and the screen sees the stop is checked in and moves on.
    if (stop.status == VisitStatus.checkedIn ||
        stop.status == VisitStatus.checkedOut) {
      emit(_answered(current, attempt));
      return;
    }

    var vpnDetected = false;
    try {
      vpnDetected = await _fraudDetectionService.detectVpnHeuristic();
    } catch (_) {}

    final decision = decideCheckIn(
      current: current,
      service: _fraudDetectionService,
      policy: _policy,
      vpnDetected: vpnDetected,
      overrideReason: event.overrideReason,
    );
    for (final flag in decision.flags) {
      unawaited(_recordFraudFlag(FraudFlag(
        id: newRouteEventId(),
        routeId: current.route.id,
        stopId: stop.id,
        type: flag.type,
        detail: flag.detail,
        timestamp: DateTime.now(),
        blocked: false,
      )));
    }

    if (!decision.allowed) {
      emit(current.copyWith(
        checkInSaveFailed: false,
        checkInRefusal: () => null,
        blockedCheckInReason: () => decision.blockedReason,
        checkInWarnings: decision.warnings,
        checkInOverridable: decision.overridable,
        checkInAttempt: attempt,
      ));
      return;
    }

    final now = DateTime.now();
    final record = buildCheckInRecord(
      current: current,
      stop: stop,
      now: now,
      overrideReason: decision.storedReason,
    );
    final outcome = await _submission.submit(record);
    final latest = state;
    final base = latest is ActiveRouteReady ? latest : current;
    switch (outcome) {
      case CheckInSaveFailed():
        emit(_answered(base, attempt, saveFailed: true));
        return;
      case CheckInRefused(:final status):
        emit(_answered(base, attempt, refusal: status));
        return;
      case CheckedIn():
        break;
    }

    // Built on the *latest* state, not the snapshot from before the awaits:
    // GPS updates that arrived meanwhile must not be rolled back.
    final next = base.copyWith(
      currentStopIndex: current.currentStopIndex,
      route: base.route.copyWith(
          stops: _replaceStop(
              base.route.stops,
              stop.id,
              (s) => s.copyWith(
                  status: VisitStatus.checkedIn, actualArrival: now))),
      blockedCheckInReason: () => null,
      checkInWarnings: decision.warnings,
      checkInOverridable: false,
      checkInAttempt: attempt,
      checkInSaveFailed: false,
      checkInRefusal: () => null,
    );
    emit(next);
    _persistWorkflow(next);
  }

  /// [base] answering check-in [attempt], so the screen's spinner stops.
  ActiveRouteReady _answered(
    ActiveRouteReady base,
    int attempt, {
    String? blockedReason,
    bool saveFailed = false,
    VisitSendStatus? refusal,
  }) =>
      base.copyWith(
        checkInAttempt: attempt,
        blockedCheckInReason: () => blockedReason,
        checkInOverridable: false,
        checkInSaveFailed: saveFailed,
        checkInRefusal: () => refusal,
      );

  Future<void> _onCheckOut(
      CheckOutRequested event, Emitter<ActiveRouteState> emit) async {
    final current = state;
    if (current is! ActiveRouteReady || !current.hasCurrentStop) return;
    final stop = current.route.stops[current.currentStopIndex];
    if (stop.status != VisitStatus.checkedIn) return;

    final now = DateTime.now();
    final duration = stop.actualArrival == null
        ? 0
        : now.difference(stop.actualArrival!).inMinutes;
    final record = CheckOutRecord(
      id: newRouteEventId(),
      stopId: stop.id,
      timestamp: now,
      // Same correction as the check-in record above: where the rep was, not
      // where the shop is.
      latitude: current.repLatitude ?? stop.depot.latitude,
      longitude: current.repLongitude ?? stop.depot.longitude,
      durationMinutes: duration,
      visitSummary: event.visitSummary,
    );
    await _checkOut(record);
    await _updateStopStatus(
      UpdateStopStatusParams(
          stopId: stop.id,
          status: VisitStatus.checkedOut,
          actualDeparture: now),
    );

    final next = current.copyWith(
      route: current.route.copyWith(
          stops: _replaceStop(
              current.route.stops,
              stop.id,
              (s) => s.copyWith(
                  status: VisitStatus.checkedOut, actualDeparture: now))),
    );
    emit(next);
    _persistWorkflow(next);
  }

  Future<void> _onNextStop(
      NextStopRequested event, Emitter<ActiveRouteState> emit) async {
    final current = state;
    if (current is! ActiveRouteReady || !current.hasCurrentStop) return;
    final stop = current.route.stops[current.currentStopIndex];

    var stops = current.route.stops;
    if (stop.status != VisitStatus.checkedOut) {
      await _updateStopStatus(
          UpdateStopStatusParams(stopId: stop.id, status: VisitStatus.missed));
      stops = _replaceStop(
          stops, stop.id, (s) => s.copyWith(status: VisitStatus.missed));
    }

    final nextIndex = current.currentStopIndex + 1;
    final next = current.copyWith(
      route: current.route.copyWith(stops: stops),
      currentStopIndex:
          nextIndex < stops.length ? nextIndex : current.currentStopIndex,
      insideGeofence: false,
      blockedCheckInReason: () => null,
      checkInWarnings: const [],
      checkInSaveFailed: false,
      checkInRefusal: () => null,
    );
    emit(next);
    _persistWorkflow(next);
  }

  /// Skips [event.index], marking it [VisitStatus.missed] and keeping the
  /// rep's reason in state. Works whether or not the day has started, and never
  /// re-skips an already resolved (checked-out / missed) stop. Advancing the
  /// "next" pointer is left to the derived `_nextIndex` the screen recomputes.
  Future<void> _onSkipStop(
      SkipStopRequested event, Emitter<ActiveRouteState> emit) async {
    final current = state;
    if (current is! ActiveRouteReady) return;
    if (event.index < 0 || event.index >= current.route.stops.length) return;
    final stop = current.route.stops[event.index];
    if (stop.status == VisitStatus.checkedOut ||
        stop.status == VisitStatus.missed) {
      return;
    }

    await _updateStopStatus(
        UpdateStopStatusParams(stopId: stop.id, status: VisitStatus.missed));

    final next = current.copyWith(
      route: current.route.copyWith(
        stops: _replaceStop(current.route.stops, stop.id,
            (s) => s.copyWith(status: VisitStatus.missed)),
      ),
      skipReasons: {...current.skipReasons, stop.id: event.reason},
    );
    emit(next);
    _persistWorkflow(next);
  }

  Future<void> _onEndDay(
      EndDayRequested event, Emitter<ActiveRouteState> emit) async {
    final current = state;
    if (current is! ActiveRouteReady) return;
    await _updateRouteStatus(
        UpdateRouteStatusParams(current.route.id, RouteStatus.completed));
    unawaited(_clearActiveWorkflow(const NoParams()));
    emit(ActiveRouteCompleted(
        current.route.copyWith(status: RouteStatus.completed)));
  }

  List<RouteStop> _replaceStop(List<RouteStop> stops, String stopId,
          RouteStop Function(RouteStop) update) =>
      [
        for (final s in stops)
          if (s.id == stopId) update(s) else s
      ];
}
