import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_visit_outcome.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_ad_hoc_visit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/ad_hoc_visit_state.dart';

/// Drives "add a depot the Call Plan missed to today".
///
/// Deliberately small: the visit walks the *same* lifecycle as every other
/// stop once it exists, so there is no check-in, geofence or photo code here.
/// This cubit only gets the stop created and keeps the retry queue honest.
class AdHocVisitCubit extends Cubit<AdHocVisitState> {
  AdHocVisitCubit({
    required AddAdHocVisit addAdHocVisit,
    required DrainAdHocVisitQueue drainQueue,
    required GetDepotIdsOnDay depotIdsOnDay,
    required WatchPendingAdHocVisits watchPending,
  })  : _add = addAdHocVisit,
        _drain = drainQueue,
        _depotIdsOnDay = depotIdsOnDay,
        _watchPending = watchPending,
        super(const AdHocVisitState());

  final AddAdHocVisit _add;
  final DrainAdHocVisitQueue _drain;
  final GetDepotIdsOnDay _depotIdsOnDay;
  final WatchPendingAdHocVisits _watchPending;

  StreamSubscription<List<PendingAdHocVisit>>? _pendingSub;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _pendingSub = _watchPending(const NoParams()).listen(
      (rows) {
        if (!isClosed) emit(state.copyWith(pending: rows));
      },
      // A failed watch must not take the dashboard down — the queue is a
      // convenience on top of an action that already reported its own result.
      onError: (Object _) {},
    );
  }

  /// Refreshes the set of depots already on [day], so the picker can exclude
  /// them. Called when the picker opens and when the selected date changes.
  Future<void> refreshDepotsOnDay(DateTime day) async {
    final result = await _depotIdsOnDay(day);
    if (isClosed) return;
    result.when(
      success: (ids) => emit(state.copyWith(depotIdsOnDay: ids)),
      failure: (_) {},
    );
  }

  /// One user tap. Guarded against a double tap: a second request would carry
  /// a second `clientRequestId` and therefore create a second visit.
  Future<void> addDepot({
    required String depotId,
    required String sk,
    required String depotName,
  }) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(
        status: AdHocVisitStatus.submitting, effect: () => null));

    final result = await _add(
        AddAdHocVisitParams(depotId: depotId, sk: sk, depotName: depotName));
    if (isClosed) return;

    result.when(
      success: (outcome) => emit(state.copyWith(
        status: AdHocVisitStatus.idle,
        effect: () => switch (outcome) {
          AdHocVisitAdded(:final stop) => AdHocVisitCreated(
              stopId: stop.id,
              depotName: depotName,
            ),
          AdHocVisitAlreadyOnToday(depotId: final id) =>
            AdHocVisitAlreadyThere(depotId: id, depotName: depotName),
          AdHocVisitQueued() => AdHocVisitWaiting(depotName: depotName),
        },
      )),
      failure: (failure) => emit(state.copyWith(
        status: AdHocVisitStatus.idle,
        // A 403 saying "you are not a field rep" hides the action for the
        // session. It does **not** sign anyone out — that is reserved for a
        // 401, and conflating the two logs out every non-rep who taps once.
        hidden: failure is AdHocVisitRefusedFailure &&
            failure.isPermanentlyUnavailable,
        effect: () => AdHocVisitRefused(
          message: failure.message,
          supportReference: failure is AdHocVisitRefusedFailure
              ? failure.supportReference
              : null,
        ),
      )),
    );
  }

  /// Retries whatever is queued. Safe to call on every reconnect and on every
  /// pull-to-refresh — draining twice is harmless by design.
  Future<bool> drainQueue() async {
    final result = await _drain(const NoParams());
    if (isClosed) return false;
    return result.when(
      // True when anything actually reached the server, so the caller knows
      // whether a route refresh is worth the round trip.
      success: (delivered) => delivered.isNotEmpty,
      failure: (_) => false,
    );
  }

  /// Marks the one-shot effect as handled, so a rebuild does not replay it.
  void clearEffect() {
    if (state.effect == null) return;
    emit(state.copyWith(effect: () => null));
  }

  @override
  Future<void> close() {
    _pendingSub?.cancel();
    return super.close();
  }
}
