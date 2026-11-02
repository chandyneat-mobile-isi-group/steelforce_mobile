import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out_visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/plan_check_out_state.dart';

/// Checks the rep out of one planned visit
/// (`POST /api/v1/mobile/plans/{id}/check-out`).
///
/// The check-out id is made once per cubit and sent on every attempt, so a
/// retry after a lost answer gets the closed visit back, not a 409.
class PlanCheckOutCubit extends Cubit<PlanCheckOutState> {
  PlanCheckOutCubit({
    required CheckOutVisitPlan checkOut,
    required LocationFixProvider location,
    String Function() newId = Uuid.v4,
  })  : _checkOut = checkOut,
        _location = location,
        _checkOutId = newId(),
        super(const PlanCheckOutState());

  final CheckOutVisitPlan _checkOut;
  final LocationFixProvider _location;
  final String _checkOutId;

  static const _fixTimeout = Duration(seconds: 15);
  static const _staleFix = Duration(minutes: 2);

  /// The fix a check-out needs, then the request. Returns true once the
  /// server has closed the visit. A second tap while one is running is
  /// ignored.
  Future<bool> checkOut(String planId, {String? notes}) async {
    if (state.busy || state.stage == PlanCheckOutStage.done) {
      return state.stage == PlanCheckOutStage.done;
    }
    emit(const PlanCheckOutState(stage: PlanCheckOutStage.locating));
    final fix = await _fix();
    if (isClosed) return false;
    if (fix == null) {
      emit(const PlanCheckOutState(noLocation: true));
      return false;
    }

    emit(const PlanCheckOutState(stage: PlanCheckOutStage.sending));
    final result = await _checkOut(PlanCheckOutRequest(
      planId: planId,
      checkOutId: _checkOutId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracyMeters: fix.accuracyMeters,
      // Free text about the visit; left out of the request when blank.
      notes: notes,
    ));
    if (isClosed) return false;
    switch (result) {
      case Success(:final data):
        emit(PlanCheckOutState(
            stage: PlanCheckOutStage.done,
            queued: data == PlanStepDelivery.queued));
        return true;
      case Failed(:final failure):
        emit(PlanCheckOutState(failure: failure));
        return false;
    }
  }

  /// A fresh fix; falls back to a recent cached one rather than none.
  Future<LocationSample?> _fix() async {
    final availability = await _location.checkAvailability();
    if (availability != LocationAvailability.available) return null;
    return await _location.currentFix(precise: true, timeout: _fixTimeout) ??
        await _location.lastKnownFix(maxAge: _staleFix);
  }
}
