import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_in_visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_plan_check_in_target.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/plan_check_in_state.dart';

/// Checks the rep in at one planned visit
/// (`POST /api/v1/mobile/plans/{id}/check-in`).
///
/// The check-in id is made once per screen and sent on every attempt, so a
/// retry after a lost answer is the same check-in, not a second one.
class PlanCheckInCubit extends Cubit<PlanCheckInState> {
  PlanCheckInCubit({
    required GetPlanCheckInTarget getTarget,
    required CheckInVisitPlan checkIn,
    required LocationFixProvider location,
    AppLogger? logger,
    String Function() newId = Uuid.v4,
  })  : _getTarget = getTarget,
        _checkIn = checkIn,
        _location = location,
        _logger = logger,
        _checkInId = newId(),
        super(const PlanCheckInState());

  final GetPlanCheckInTarget _getTarget;
  final CheckInVisitPlan _checkIn;
  final LocationFixProvider _location;
  final AppLogger? _logger;
  final String _checkInId;

  static const _fixTimeout = Duration(seconds: 15);
  static const _staleFix = Duration(minutes: 2);

  /// Reads the plan's depot location and starts looking for a GPS fix.
  /// [locateNow] false when the screen streams fixes in through [useFix].
  Future<void> start(String planId, {bool locateNow = true}) async {
    emit(state.copyWith(stage: PlanCheckInStage.loading, failure: () => null));
    final locating = locateNow ? locate() : Future<void>.value();
    final result = await _getTarget(planId);
    if (isClosed) return;
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(stage: PlanCheckInStage.ready, target: data));
      case Failed(:final failure):
        emit(state.copyWith(
            stage: PlanCheckInStage.loadFailed, failure: () => failure));
    }
    await locating;
  }

  /// A fresh fix; falls back to a recent cached one rather than none.
  Future<void> locate() async {
    emit(state.copyWith(fixStatus: PlanFixStatus.locating));
    final availability = await _location.checkAvailability();
    final fix = availability == LocationAvailability.available
        ? await _location.currentFix(precise: true, timeout: _fixTimeout) ??
            await _location.lastKnownFix(maxAge: _staleFix)
        : null;
    if (isClosed) return;
    emit(fix == null
        ? state.copyWith(fixStatus: PlanFixStatus.unavailable)
        : state.copyWith(fix: fix, fixStatus: PlanFixStatus.found));
  }

  /// A fix from the screen's live location stream; null when it has none.
  void useFix(LocationSample? fix) => emit(fix == null
      ? state.copyWith(fixStatus: PlanFixStatus.unavailable)
      : state.copyWith(fix: fix, fixStatus: PlanFixStatus.found));

  void addPhoto(String path) {
    if (!state.canAddPhoto) return;
    emit(state.copyWith(photos: [...state.photos, path]));
  }

  void removePhoto(String path) => emit(state.copyWith(
      photos: [...state.photos]..remove(path), failure: () => null));

  /// Sends the check-in. Returns false without sending when one is already
  /// on its way, or the form is not complete: no fix, no photo, or a reason
  /// the zone requires is missing. [notes] is optional.
  Future<bool> submit({
    PlanCheckInReason? reason,
    String? description,
    String? notes,
  }) async {
    // First: a second tap while the first is in flight must not send twice.
    if (state.stage == PlanCheckInStage.submitting) {
      _logger?.debug('checkIn.submit.ignored',
          fields: {'checkInId': _checkInId, 'reason': 'in_flight'});
      return false;
    }
    final target = state.target;
    final fix = state.fix;
    // Picking a reason is enough: its own wording is the description the
    // server requires, unless the rep wrote one.
    final typed = description?.trim() ?? '';
    final note = typed.isNotEmpty ? typed : (reason?.description ?? '');
    final missing = [
      if (target == null) 'plan',
      if (fix == null) 'location',
      if (state.photos.isEmpty) 'photos',
      if (state.needsReason && reason == null) 'reasonCode',
      if (state.needsReason && note.isEmpty) 'reasonDescription',
    ];
    _logger?.debug(
        missing.isEmpty
            ? 'checkIn.validation.passed'
            : 'checkIn.validation.failed',
        fields: {
          'planId': target?.planId,
          'checkInId': _checkInId,
          if (missing.isNotEmpty) 'missing': missing,
          'accuracyMeters': fix?.accuracyMeters.round(),
          'distanceMeters': state.distanceMeters?.round(),
          'radiusMeters': target?.radiusMeters?.round(),
          'outsideZone': state.outsideZone,
          'reasonRequired': state.needsReason,
          'photoCount': state.photos.length,
        });
    if (target == null || fix == null || missing.isNotEmpty) return false;

    emit(state.copyWith(
        stage: PlanCheckInStage.submitting, failure: () => null));
    final result = await _checkIn(PlanCheckInRequest(
      planId: target.planId,
      checkInId: _checkInId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracyMeters: fix.accuracyMeters,
      photoPaths: state.photos,
      reason: state.needsReason ? reason : null,
      reasonDescription: state.needsReason ? note : null,
      notes: notes,
    ));
    if (isClosed) return false;
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(stage: PlanCheckInStage.done, result: data));
        return true;
      case Failed(:final failure):
        emit(state.copyWith(
          stage: PlanCheckInStage.ready,
          reasonRequired: state.reasonRequired || _asksForReason(failure),
          failure: () => failure,
        ));
        return false;
    }
  }

  static bool _asksForReason(Failure failure) =>
      failure is ServerFailure && failure.code == planCheckInReasonRequiredCode;
}
