import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/services/outlet_location_source.dart';
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
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';
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

  /// Fire-and-forget resume-pointer upsert — advisory (stop status in the
  /// DB is the real source of truth on resume), so a slow/failed write here
  /// never blocks the UI.
  ///
  /// When the current stop is checked in, the pointer is enriched into a
  /// *workflow-aware* row: Shop/Depot + check-in time + a baseline
  /// [VisitWorkflow.stockCount] (the guided step that immediately follows
  /// check-in) + the [navigationArguments] the resume dispatcher needs to
  /// rebuild the exact screen. Business-task transitions (Quotation/Sales Order)
  /// layer onto this via [UpdateWorkflowStep]. When the stop is not checked in
  /// (before check-in or after check-out), the workflow fields are cleared so
  /// resume falls back to the guided route flow.
  void _persistWorkflow(ActiveRouteReady state) {
    // Gated on `dayStarted` alone, this silently refused to write the pointer
    // for a stop that was genuinely checked in — the same class of silent
    // block `_onGeofenceChanged` documents below.
    //
    // Entering through Stop Dashboard -> Stop Information -> Check-in loads
    // the route fresh, so before the fix in `_onLoad` the flag was always down
    // here. The check-in succeeded and pushed, but no workflow row was
    // written, so `CompleteVisitCheckOut` had nothing to close: it logged
    // `visit.checkout.skipped reason=noActiveWorkflow`, wrote no check-out and
    // no status update, and the stop card sat on "In Progress" forever.
    //
    // A checked-in stop *is* a live visit whatever the day flag says, and a
    // visit that cannot be resumed is a visit that cannot be completed.
    final stop =
        state.hasCurrentStop ? state.route.stops[state.currentStopIndex] : null;
    if (!state.dayStarted && stop?.status != VisitStatus.checkedIn) return;
    unawaited(_writeWorkflowPointer(state));
  }

  Future<void> _writeWorkflowPointer(ActiveRouteReady state) async {
    final stop =
        state.hasCurrentStop ? state.route.stops[state.currentStopIndex] : null;
    final isActive = stop != null && stop.status == VisitStatus.checkedIn;
    final now = DateTime.now();

    if (!isActive) {
      // Only drop the pointer when there is no live visit left anywhere on the
      // route. Merely *selecting* a different stop while one is still checked
      // in used to clear it, which is the other way a visit became impossible
      // to close: the check-out found no workflow and skipped, leaving the
      // stop on "In Progress" with no way back into it.
      final hasLiveVisit =
          state.route.stops.any((s) => s.status == VisitStatus.checkedIn);
      if (!hasLiveVisit) await _clearActiveWorkflow(const NoParams());
      return;
    }

    // Baseline for a live visit: the guided Stock Count step, which now sits
    // between check-in and the Quotation Builder. A fresh check-in with no
    // further progress resumes here; [UpdateWorkflowStep] overwrites this once
    // the rep advances into a business task (see the guard below).
    VisitWorkflow? workflow = VisitWorkflow.stockCount;
    String? screen = InventoryVisibilityScreen.routeName;
    Map<String, dynamic>? args = {
      'stopId': stop.id,
      'depotId': stop.depot.id,
      'depotName': stop.depot.name,
      'territory': stop.depot.territory,
    };

    // Never *downgrade* a business task the rep already advanced into
    // (Quotation/Sales Order) back to Stock Count when a later route event
    // re-persists for the same stop — that would strand "Continue Working" on
    // the wrong screen. Deferred check-out means the stop stays checked in
    // through those tasks, so this guard keeps the resume pointer stable.
    if (isActive) {
      final existingResult = await _getActiveWorkflow(const NoParams());
      final existing =
          existingResult.when(success: (w) => w, failure: (_) => null);
      final sameStop = existing != null && existing.currentStopId == stop.id;

      if (sameStop && (existing.currentWorkflow?.isBusinessTask ?? false)) {
        workflow = existing.currentWorkflow;
        screen = existing.currentScreen;
        args = existing.navigationArguments ?? args;
      } else if (sameStop) {
        // Same stop, still on a guided step: refresh the baseline keys but
        // keep anything a step recorded for itself.
        //
        // This is what was destroying in-progress work. A guided step is not a
        // "business task", so the branch above never protected it, and any
        // later route event re-ran this write and replaced the whole argument
        // map — taking the half-finished stock audit with it. The rep tapped
        // four items, the app saved them, and the next route rebuild wiped
        // them. Merging keeps the step's own state alive while the baseline
        // stays authoritative for the keys it owns.
        args = {...?existing.navigationArguments, ...args};
        // Keep a more advanced guided screen (e.g. the post-audit decision)
        // rather than resetting to the audit the rep already finished.
        screen = existing.currentScreen ?? screen;
      }
    }

    await _saveActiveWorkflow(ActiveWorkflow(
      routeId: state.route.id,
      currentStopId: stop.id,
      dayStarted: state.dayStarted,
      updatedAt: now,
      depotId: isActive ? stop.depot.id : null,
      shopName: isActive ? stop.depot.name : null,
      checkInAt: isActive ? stop.actualArrival : null,
      currentWorkflow: workflow,
      currentScreen: screen,
      navigationArguments: args,
      workflowUpdatedAt: isActive ? now : null,
    ));
  }

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
      emit(current.copyWith(
        checkInAttempt: attempt,
        blockedCheckInReason: () =>
            'No stop selected — go back and open the stop again.',
        checkInOverridable: false,
        checkInSaveFailed: false,
        checkInRefusal: () => null,
      ));
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
      emit(current.copyWith(
        checkInAttempt: attempt,
        blockedCheckInReason: () => null,
        checkInOverridable: false,
        checkInSaveFailed: false,
        checkInRefusal: () => null,
      ));
      return;
    }

    var vpnDetected = false;
    try {
      vpnDetected = await _fraudDetectionService.detectVpnHeuristic();
    } catch (_) {}

    // Three different situations reach the geofence rule, and only one of them
    // is the rep's doing.
    //
    // - Inside / outside a known geofence with a known position → the real
    //   verdict, enforced.
    // - **No GPS fix yet** → nothing has been measured. Blocking here is what
    //   made check-in impossible: `_onStopSelected` writes
    //   `insideGeofence: false`, and until a fix arrives there is nothing to
    //   overwrite it with. A rep in a metal-roofed warehouse would wait
    //   forever for a verdict that says only "we did not look".
    // - **Depot has no coordinates** → there is no geofence to be outside
    //   of (`GeofenceService.evaluate` returns `locationKnown: false` for
    //   exactly this).
    //
    // The last two record the visit as *unverifiable* — a warning on the row,
    // which the server already knows how to read (api.md §8.2: evidence, not a
    // verdict; a check-in with no fix is stored as unverifiable). They do not
    // refuse the work.
    final unverifiable = !current.hasFix || !current.depotLocationKnown;
    final validation = _fraudDetectionService.validateCheckIn(
      insideGeofence: unverifiable ? true : current.insideGeofence,
      accuracyMeters: current.accuracyMeters,
      isMocked: current.isMocked,
      vpnDetected: vpnDetected,
      policy: _policy,
    );

    final warnings = <String>[
      ...validation.warnings,
      if (!current.hasFix)
        'No GPS fix yet — this check-in is recorded as unverified.',
      if (!current.depotLocationKnown)
        'This depot has no recorded location — the geofence could not be checked.',
    ];

    for (final warning in validation.warnings) {
      unawaited(_recordFraudFlag(FraudFlag(
        id: _newId(),
        routeId: current.route.id,
        stopId: stop.id,
        type: current.isMocked
            ? FraudFlagType.mockLocation
            : FraudFlagType.vpnDetected,
        detail: warning,
        timestamp: DateTime.now(),
        blocked: false,
      )));
    }

    // A written reason carries the check-in past the location rules — and only
    // those. `canOverrideWithReason` is false the moment an integrity rule is
    // among the blocks, so a mocked position cannot be typed past.
    final reason = event.overrideReason?.trim() ?? '';
    final overrideOffered = _policy.allowReasonedCheckInOverride &&
        validation.canOverrideWithReason;
    final overrideAccepted =
        overrideOffered && reason.length >= _policy.minOverrideReasonLength;

    if (!validation.allowed && !overrideAccepted) {
      emit(current.copyWith(
        checkInSaveFailed: false,
        checkInRefusal: () => null,
        blockedCheckInReason: () => validation.blockedReasons.join(' '),
        checkInWarnings: warnings,
        // Tells the screen whether to offer "check in anyway" or just report
        // the block. Without it the UI would have to re-derive the rule split
        // by matching on message text.
        checkInOverridable: overrideOffered,
        checkInAttempt: attempt,
      ));
      return;
    }

    // A reason the rep gave that the location rules did not strictly need.
    //
    // The main case: no fix at all (or a shop with no pin), which was already
    // allowed through as *unverified* — and the check-in dialog's "Check in
    // without GPS" path always asks why. Keep that reason on the row.
    // Otherwise the check-in with the least location evidence would be the
    // only kind whose explanation is thrown away.
    //
    // Also covers a rep whose screen had no *fresh* fix while this bloc still
    // held an older one: the rep answered a question, so the answer is kept.
    final extraReasonGiven =
        !overrideAccepted && reason.length >= _policy.minOverrideReasonLength;
    if (extraReasonGiven) {
      final String situation;
      if (!current.hasFix) {
        situation = 'No GPS fix.';
      } else if (!current.depotLocationKnown) {
        situation = 'Depot has no recorded location.';
      } else {
        situation = 'No fresh GPS fix on screen.';
      }
      unawaited(_recordFraudFlag(FraudFlag(
        id: _newId(),
        routeId: current.route.id,
        stopId: stop.id,
        type: FraudFlagType.reasonedOverride,
        detail: '$situation Reason: $reason',
        timestamp: DateTime.now(),
        blocked: false,
      )));
      warnings.add('Checked in without location verification. Reason: $reason');
    }

    if (overrideAccepted) {
      // Recorded in the fraud trail, not just in the note. The note travels
      // with the visit and is what a supervisor reads; the flag is what makes
      // override *frequency* answerable without parsing free text.
      unawaited(_recordFraudFlag(FraudFlag(
        id: _newId(),
        routeId: current.route.id,
        stopId: stop.id,
        type: FraudFlagType.reasonedOverride,
        detail: '${validation.overridableReasons.join(' ')} Reason: $reason',
        timestamp: DateTime.now(),
        blocked: false,
      )));
      warnings.add('Checked in outside the geofence. Reason: $reason');
    }

    final now = DateTime.now();
    final record = CheckInRecord(
      id: _newId(),
      stopId: stop.id,
      timestamp: now,
      // **The rep's position, not the shop's.** These two fields are the
      // geofence evidence the server judges the visit on (api.md §8.2), and
      // this used to send `stop.depot.latitude/longitude` — the shop's own
      // pin. Every check-in then arrived reading as exactly on-location,
      // whoever sent it and from wherever, which makes the server-side check
      // structurally incapable of catching anything.
      //
      // Falls back to the depot pin only when there is no fix at all, and
      // that row is already flagged unverified in `warnings` above, so the
      // server can tell the difference between measured and assumed.
      //
      // TODO(release-gate): `kUseStaticCheckInPosition` replaces both with a
      // stand-in (the stop's own pin) in debug builds so the push contract can
      // be exercised without a usable GPS. It is `kDebugMode`-gated and cannot
      // reach release, but while it is on every check-in reports itself as
      // exactly on-location — see the flag's own doc for what that costs.
      latitude: kUseStaticCheckInPosition
          ? staticCheckInPositionFor(stop.depot).latitude
          : current.repLatitude ?? stop.depot.latitude,
      longitude: kUseStaticCheckInPosition
          ? staticCheckInPositionFor(stop.depot).longitude
          : current.repLongitude ?? stop.depot.longitude,
      accuracyMeters: current.accuracyMeters,
      distanceFromDepotMeters: current.distanceMeters,
      isMocked: current.isMocked,
      // Travels on the check-in row, so the reason and the verdict it explains
      // are one record. Null unless the rep actually overrode something —
      // `overrideAccepted` is false both for an ordinary check-in and for a
      // reason too short to have been meant.
      overrideReason: (overrideAccepted || extraReasonGiven) ? reason : null,
      routeId: current.route.id,
    );
    // The local save is the check-in. If it did not land, nothing was
    // recorded and the rep must be told so — never shown a success.
    //
    // `CheckIn` reports a failed write as a `Failed` result, not a throw. The
    // handler used to only `catch`, so a `CacheFailure` from the repository
    // sailed straight past it: the stop was marked checked in on screen, the
    // rep was moved on into the visit, and no check-in row existed to push.
    // Both shapes are now answered the same way: a typed
    // `checkInSaveFailed` state the screen renders as a localized message.
    final saveFailed = await _saveCheckIn(record);
    if (saveFailed) {
      final latest = state;
      emit((latest is ActiveRouteReady ? latest : current).copyWith(
        checkInAttempt: attempt,
        blockedCheckInReason: () => null,
        checkInOverridable: false,
        checkInSaveFailed: true,
        checkInRefusal: () => null,
      ));
      return;
    }

    // Saved. Online, the server sees it now; offline it waits for the next
    // sync and the rep carries on regardless. Only a definite refusal stops
    // the check-in — the repository has already dropped the row then.
    final refusal = await _offerToServer(record);
    if (refusal != null) {
      final latest = state;
      emit((latest is ActiveRouteReady ? latest : current).copyWith(
        checkInAttempt: attempt,
        blockedCheckInReason: () => null,
        checkInOverridable: false,
        checkInSaveFailed: false,
        checkInRefusal: () => refusal,
      ));
      return;
    }
    // The check-in row exists now. If the status update fails, still move the
    // rep on — retrying would write a second check-in row for the same visit.
    try {
      final statusResult = await _updateStopStatus(UpdateStopStatusParams(
          stopId: stop.id, status: VisitStatus.checkedIn, actualArrival: now));
      // The failure's message wraps raw database text, which can quote row
      // values — only the fact of the failure is reported.
      if (statusResult is Failed) {
        addError(StateError('stop status not saved'), StackTrace.current);
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }

    // Built on the *latest* state, not the snapshot from before the awaits:
    // GPS updates that arrived meanwhile must not be rolled back.
    final latest = state;
    final base = latest is ActiveRouteReady ? latest : current;
    final next = base.copyWith(
      currentStopIndex: current.currentStopIndex,
      route: base.route.copyWith(
          stops: _replaceStop(
              base.route.stops,
              stop.id,
              (s) => s.copyWith(
                  status: VisitStatus.checkedIn, actualArrival: now))),
      blockedCheckInReason: () => null,
      checkInWarnings: warnings,
      checkInOverridable: false,
      checkInAttempt: attempt,
      checkInSaveFailed: false,
      checkInRefusal: () => null,
    );
    emit(next);
    _persistWorkflow(next);
  }

  /// The server's definite refusal of [record], or null — sent, queued, or
  /// not wired. A failure to even ask is never a refusal.
  Future<VisitSendStatus?> _offerToServer(CheckInRecord record) async {
    final send = _sendCheckIn;
    if (send == null) return null;
    try {
      final result = await send(record);
      return result.when(
        success: (r) => r.refused ? r.status : null,
        failure: (_) => null,
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return null;
    }
  }

  /// Writes the check-in row. Returns true when it was **not** saved — either
  /// a `Failed` result or a throw — so the caller can refuse to report success.
  Future<bool> _saveCheckIn(CheckInRecord record) async {
    try {
      final result = await _checkIn(record);
      if (result is Failed) {
        // Not the failure's message: it wraps raw database text.
        addError(StateError('check-in not saved'), StackTrace.current);
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return true;
    }
  }

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
      id: _newId(),
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

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';
}
