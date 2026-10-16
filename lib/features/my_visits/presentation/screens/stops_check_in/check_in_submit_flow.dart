part of '../stops_check_in_screen.dart';

/// The check-in submission flow: verify, confirm, dispatch, wait for the
/// bloc's answer, and navigate on to the visit.
extension _CheckInSubmitFlow on _RouteCheckInScreenState {
  void _onSubmitTimeout() {
    if (!mounted || !_submitting) return;
    _endSubmit();
    final bloc = _resolveBloc<ActiveRouteBloc>(context);
    final live = _liveStop(bloc.state, _stopId);
    // It may have landed after all — the answer was just not seen.
    if (_isCheckedIn(live)) {
      _goToVisit(context, live!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // TODO(i18n)
        content: const Text(
            'Check-in did not respond. Please check your connection and try again.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Advances only once the check-in has actually landed.
  ///
  /// Keyed on `checkInAttempt`, not on "the state changed": a refusal with the
  /// same reason as last time, or a stop that was already checked in, used to
  /// produce no new state at all — and the spinner never stopped. Every
  /// attempt now bumps the counter, so every attempt is answered.
  void _onCheckInSettled(BuildContext context, ActiveRouteState state) {
    final awaiting = _awaitingAttempt;
    if (!_submitting || awaiting == null || state is! ActiveRouteReady) return;
    if (state.checkInAttempt <= awaiting) return;

    _endSubmit();

    final live = _liveStop(state, _stopId);
    if (_isCheckedIn(live)) {
      _goToVisit(context, live!);
      return;
    }

    // Some blocks a rep can answer for — a depot gate far from the office
    // pin, a warehouse with no sky. Those get the reason sheet. The rest
    // (mock location, VPN, a failed save) only get the banner, which already
    // renders `blockedCheckInReason` in place.
    if (state.blockedCheckInReason != null && state.checkInOverridable) {
      unawaited(_offerOverride(context, state));
    }
  }

  /// Offers the reasoned override, and re-runs check-in with what the rep
  /// wrote.
  ///
  /// The reason rides on the check-in row itself (`CheckInRecord.overrideReason`
  /// → `overrideReason` on the wire), not as a separate `VisitNote`. Two rows
  /// would mean the verdict and its explanation live in different tables, and a
  /// reviewer asking "which overrides happened and why" would be joining a
  /// flagged check-in to free text somebody hoped was there. One row cannot come
  /// apart.
  Future<void> _offerOverride(
      BuildContext context, ActiveRouteReady state) async {
    final reason = await RemoteCheckInSheet.show(
      context,
      blockedReason: state.blockedCheckInReason ?? '',
      distanceMeters: state.distanceMeters,
      minLength: const FraudPolicy().minOverrideReasonLength,
    );
    if (reason == null || !mounted) return;

    // `this.context`, not the parameter. `mounted` is the State's flag, so it
    // only vouches for the State's own context — reading the passed-in one
    // after an await is guarded by something unrelated to it, which is exactly
    // what `use_build_context_synchronously` is pointing at. They are the same
    // element in practice today; using the one the guard covers keeps that
    // true if a caller ever passes a context from a subtree that can go away
    // while the sheet is open.
    final bloc = _resolveBloc<ActiveRouteBloc>(this.context);
    _beginSubmit(bloc);
    bloc.add(CheckInRequested(overrideReason: reason, stopId: _stopId));
  }

  /// Begins the screen-scoped position stream and seeds the geofence verdict
  /// from whatever fix already exists.
  ///
  /// The seed matters even once observation is running: the listener fires on
  /// *change*, and a stationary device may not produce one for seconds — or at
  /// all. Without it the bloc sits on the `insideGeofence: false` that
  /// `_onStopSelected` wrote and the first check-in is refused for no reason
  /// the rep can see.
  /// Puts the bloc into the state the check-in actually needs.
  ///
  /// `ActiveRouteBloc` refuses `CheckInRequested` unless it is
  /// `ActiveRouteReady` **with a stop selected** — and until now nothing on
  /// this path put it there. `ActiveRouteLoadRequested` was dispatched only
  /// from the legacy `Static.myVisits` route, and `StopSelected` was dispatched
  /// *nowhere at all*: only its handler existed.
  ///
  /// The result was a check-in that silently did nothing. `_onCheckIn` returned
  /// on its first guard so no row was written, and `_onCheckInSettled` returned
  /// on the same guard so `_submitting` was never cleared — the CTA span
  /// forever while the screen looked entirely healthy, because every *display*
  /// path falls back to `widget.stop` and so never needed the bloc.
  Future<void> _ensureStopSelected(RouteStop stop) async {
    final bloc = _resolveBloc<ActiveRouteBloc>(context);

    var state = bloc.state;
    if (state is! ActiveRouteReady || state.route.id != stop.routeId) {
      bloc.add(ActiveRouteLoadRequested(stop.routeId));
      try {
        state = await bloc.stream
            .firstWhere(
                (s) => s is ActiveRouteReady && s.route.id == stop.routeId)
            // Bounded: a route that never loads must leave the CTA disabled
            // rather than hang this future for the life of the screen.
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        return;
      }
    }
    if (!mounted || state is! ActiveRouteReady) return;

    final index = state.route.stops.indexWhere((s) => s.id == stop.id);
    if (index >= 0 && state.currentStopIndex != index) {
      bloc.add(StopSelected(index));
    }
  }

  Future<void> _submit(RouteStop stop) async {
    if (_submitting) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final locationCubit = _resolveBloc<LocationTrackingCubit>(context);
    final bloc = _resolveBloc<ActiveRouteBloc>(context);

    // Already checked in (came back to this screen, or an earlier answer was
    // missed): nothing to verify — go straight on.
    final alreadyIn = _liveStop(bloc.state, stop.id);
    if (_isCheckedIn(alreadyIn)) {
      _goToVisit(context, alreadyIn!);
      return;
    }

    // The bloc must hold this route before it can check anything in. If the
    // initial load has not finished (or timed out), try once more now rather
    // than dispatching into a bloc that will ignore it.
    if (bloc.state is! ActiveRouteReady ||
        _liveStop(bloc.state, stop.id) == null) {
      await _ensureStopSelected(stop);
      if (!mounted) return;
      if (_liveStop(bloc.state, stop.id) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // TODO(i18n)
            content: const Text(
                'Route is still loading. Please wait a moment and try again.'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }
    if (!mounted) return;

    // Verify, then ask. The dialog is live: it re-verifies on every fix and
    // always offers a way forward (see `CheckInConfirmationDialog`), so a rep
    // with no fix at the moment of tapping is no longer stranded on "Locating
    // You" with only Cancel.
    final choice = await CheckInConfirmationDialog.show(
      context,
      outletName: context.localized(stop.depot.displayName),
      locationCubit: locationCubit,
      read: (state) => _readLocation(stop, state),
    );
    if (choice == null || !mounted) return;

    // The reading the rep actually agreed to — the dialog's last one.
    final reading = _readLocation(stop, locationCubit.state);

    // Inside the area: nothing more to ask. Outside it, on a weak fix, or with
    // no fix at all, the rep is not blocked — the check-in just has to carry a
    // written reason, which rides on the check-in row itself. Backing out of
    // the reason sheet cancels the check-in; there is no path that records an
    // unverified one with an empty explanation.
    String? overrideReason;
    switch (choice) {
      case CheckInConfirmation.confirmed:
        break;
      case CheckInConfirmation.withReason:
        overrideReason = await RemoteCheckInSheet.show(
          context,
          blockedReason: reading.phase == CheckInGpsPhase.weakSignal
              ? 'GPS accuracy too low '
                  '(±${reading.accuracyMeters.toStringAsFixed(0)} m).'
              : 'my_visits.check_in_verification.outside_body'.tr,
          distanceMeters:
              reading.verdict.isMeasurable ? reading.distanceMeters : null,
          minLength: _policy.minOverrideReasonLength,
        );
      case CheckInConfirmation.withoutGps:
        // TODO(i18n): literals, same convention as RemoteCheckInSheet.
        overrideReason = await RemoteCheckInSheet.show(
          context,
          title: 'Check in without GPS?',
          intro: 'Your position could not be found here. You can still check '
              'in — the visit is marked unverified and your reason is sent '
              'with it.',
          blockedReason: 'No GPS position after a full search.',
          distanceMeters: null,
          minLength: _policy.minOverrideReasonLength,
          presets: RemoteCheckInSheet.noGpsPresets,
          icon: Icons.gps_off_rounded,
        );
    }
    if (choice != CheckInConfirmation.confirmed && overrideReason == null) {
      return;
    }
    if (!mounted) return;

    // Hand the bloc the exact reading the rep saw before asking it to decide.
    // Events are processed in order and the geofence handler is synchronous,
    // so the check-in below is judged on this sample, not an older one.
    _reportGeofence(bloc, locationCubit.state);

    // Dispatch and wait. `_onCheckInSettled` navigates when the stop actually
    // reaches `checkedIn`, and stays here showing the reason when the bloc
    // refuses.
    _beginSubmit(bloc);
    bloc.add(CheckInRequested(overrideReason: overrideReason, stopId: stop.id));
  }

  void _expandMap(BuildContext context, RouteStop stop) {
    final locationCubit = _resolveBloc<LocationTrackingCubit>(context);
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        fullscreenDialog: true,
        pageBuilder: (_, animation, secondaryAnimation) => BlocProvider.value(
          value: locationCubit,
          child: FadeTransition(
            opacity: animation,
            child: _FullScreenTransitMap(stop: stop),
          ),
        ),
      ),
    );
  }

  void _goToVisit(BuildContext context, RouteStop stop) {
    final navigator = Navigator.of(context);

    // No explicit workflow write here: the `CheckInRequested` dispatched in
    // `_submit` already seeds it — `ActiveRouteBloc._writeWorkflowPointer`
    // sets the baseline resume pointer to the Inventory Visibility step as
    // soon as the check-in lands.
    navigator
        .popUntil((r) => r.settings.name == StopInformationScreen.routeName);

    openInventoryStep(
      navigator.context,
      depotId: stop.depot.id,
      depotName: context.localized(stop.depot.displayName),
      stopId: stop.id,
    );
  }
}
