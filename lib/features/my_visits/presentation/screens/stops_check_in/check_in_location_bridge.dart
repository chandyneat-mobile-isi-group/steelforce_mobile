part of '../stops_check_in_screen.dart';

/// The GPS side of the check-in screen: reading the live fix, measuring it
/// against the outlet, and handing the verdict to [ActiveRouteBloc].
extension _CheckInLocationBridge on _RouteCheckInScreenState {
  /// The stop this screen is checking in to — the widget's own, or the bloc's
  /// current one when opened without it.
  RouteStop? _currentStop([ActiveRouteState? state]) {
    final s = state ?? _resolveBloc<ActiveRouteBloc>(context).state;
    return widget.stop ??
        ((s is ActiveRouteReady && s.hasCurrentStop)
            ? s.route.stops[s.currentStopIndex]
            : null);
  }

  /// Recomputes the verdict for the selected stop and hands it to the bloc.
  ///
  /// **Now the same verdict the dialog shows.** This used to run
  /// `GeofenceService.evaluate` against the *depot's* pin and territory
  /// radius (urban 50 m), while the dialog ran `CheckInLocationVerifier`
  /// against the outlet source (demo pin, 100 m). Two rules, two pins: the
  /// dialog could say "within" and the bloc then refuse "outside the
  /// geofence". Both now come from [_readLocation].
  void _reportGeofence(
      ActiveRouteBloc bloc, LocationTrackingState locationState) {
    final stop = _currentStop(bloc.state);
    if (stop == null) return;

    final reading = _readLocation(stop, locationState);
    final verdict = reading.verdict;
    final sample = locationState.usableFix();

    final standIn = staticCheckInPositionFor(stop.depot);
    final double? latitude =
        kUseStaticCheckInPosition ? standIn.latitude : sample?.latitude;
    final double? longitude =
        kUseStaticCheckInPosition ? standIn.longitude : sample?.longitude;
    // Nothing measured yet: say nothing. The bloc treats "no fix" as its own
    // case (unverified), and inventing one here would erase that distinction.
    if (latitude == null || longitude == null) return;

    bloc.add(GeofenceStatusChanged(
      insideGeofence: verdict.isWithinRadius,
      // NaN when the outlet has no pin. Sent as 0 with
      // `depotLocationKnown: false` beside it rather than as NaN, which
      // would poison `distanceFromDepot` on the pushed row — the field is a
      // number the server reads, and NaN is not one.
      distanceMeters: verdict.isMeasurable ? verdict.distanceMeters : 0,
      accuracyMeters: reading.accuracyMeters,
      isMocked: kUseStaticCheckInPosition ? false : (sample?.isMocked ?? false),
      latitude: latitude,
      longitude: longitude,
      depotLocationKnown: verdict.hasOutletLocation,
    ));
  }

  Future<void> _beginObservingLocation() async {
    final locationCubit = _resolveBloc<LocationTrackingCubit>(context);

    _reportGeofence(
        _resolveBloc<ActiveRouteBloc>(context), locationCubit.state);

    // A 10 m filter: the check-in radius is 100 m, so a rep walking the last
    // few metres to a shopfront needs to see the distance move. The dashboard's
    // 25 m default would hold a stale reading right where it matters most.
    await locationCubit.observeForScreen(distanceFilterMeters: 10);
    if (!mounted) return;

    // Re-seed once a real fix lands: the state read above was almost certainly
    // still empty.
    _reportGeofence(
        _resolveBloc<ActiveRouteBloc>(context), locationCubit.state);
  }

  /// Measures the rep against the outlet — the one verdict every location
  /// widget on this screen, the dialog, and the bloc all use.
  ///
  /// Reads the tracker's *usable* fix (recent enough to mean "now"), never a
  /// guess. No fix yet is its own verdict.
  CheckInReading _readLocation(
      RouteStop stop, LocationTrackingState locationState) {
    final sample = locationState.usableFix();

    // TODO(release-gate): while `kUseStaticCheckInPosition` is on (debug
    // builds only), the rep's position is a constant rather than the device's.
    final standIn = staticCheckInPositionFor(stop.depot);
    final deviceLatitude =
        kUseStaticCheckInPosition ? standIn.latitude : sample?.latitude;
    final deviceLongitude =
        kUseStaticCheckInPosition ? standIn.longitude : sample?.longitude;
    final accuracy =
        kUseStaticCheckInPosition ? 0.0 : (sample?.accuracyMeters ?? 0.0);

    final verdict = CheckInLocationVerifier.verify(
      outlet: _outletLocations.locationFor(stop.depot),
      deviceLatitude: deviceLatitude,
      deviceLongitude: deviceLongitude,
      fallbackRadiusMeters: _outletLocations.radiusMeters,
    );

    return CheckInReading(
      verdict: verdict,
      phase: CheckInGpsPhase.resolve(
        verdict: verdict,
        fixStatus: locationState.fixStatus,
        accuracyMeters: accuracy,
        maxAccuracyMeters: _policy.maxAccuracyMeters,
      ),
      accuracyMeters: accuracy,
      maxAccuracyMeters: _policy.maxAccuracyMeters,
      searchStartedAt: locationState.searchStartedAt,
    );
  }

  /// Retry / open-settings, from the status banner.
  void _onLocationAction(CheckInGpsPhase phase) {
    final cubit = _resolveBloc<LocationTrackingCubit>(context);
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    if (phase.isBlockedBySetting) {
      unawaited(cubit.openSettingsForStatus());
    } else {
      unawaited(cubit.retryFix());
    }
  }
}
