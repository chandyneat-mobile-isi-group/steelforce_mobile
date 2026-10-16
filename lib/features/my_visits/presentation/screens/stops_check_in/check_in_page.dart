part of '../stops_check_in_screen.dart';

/// The check-in screen's page layout.
extension _CheckInPage on _RouteCheckInScreenState {
  Widget _build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final activeRouteBloc = _resolveBloc<ActiveRouteBloc>(context);
    final visitCubit = _resolveBloc<VisitCubit>(context);
    final locationCubit = _resolveBloc<LocationTrackingCubit>(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        iconTheme: IconThemeData(color: colors.textPrimary),
        bottom: const VisitStepBar(current: VisitStep.checkIn),
        title: Text(
          'my_visits.flow.checkin_title'.tr,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          // The bridge from GPS to the bloc: every new fix — and every status
          // change, so a fix going stale is noticed — is run through the same
          // verifier the dialog uses and dispatched as `GeofenceStatusChanged`.
          // The bloc deliberately has no location dependency (it stays
          // unit-testable), so the bridge belongs here.
          BlocListener<LocationTrackingCubit, LocationTrackingState>(
            bloc: locationCubit,
            listenWhen: (previous, current) =>
                previous.current != current.current ||
                previous.fixStatus != current.fixStatus,
            listener: (context, locationState) =>
                _reportGeofence(activeRouteBloc, locationState),
          ),
          // Check-in is asynchronous and can be refused. Navigation waits for
          // the verdict instead of assuming one.
          BlocListener<ActiveRouteBloc, ActiveRouteState>(
            bloc: activeRouteBloc,
            listener: _onCheckInSettled,
          ),
        ],
        child: BlocBuilder<ActiveRouteBloc, ActiveRouteState>(
          bloc: activeRouteBloc,
          // Rebuild the page only for what it renders from the bloc. The bloc
          // also emits on every GPS sample (distance, accuracy, position), and
          // rebuilding the whole page — Google Map included — for each one is
          // what made this screen feel stuck.
          buildWhen: (previous, current) =>
              _pageKey(previous) != _pageKey(current),
          builder: (context, state) {
            final RouteStop? stop = _currentStop(state);

            if (stop == null) {
              return Center(
                child: CircularProgressIndicator(
                  color: scheme.primary,
                  strokeWidth: 2.8,
                ),
              );
            }

            final String? blockedReason = _blockedReason(state);
            final List<String> warnings =
                state is ActiveRouteReady ? state.checkInWarnings : const [];

            return BlocBuilder<VisitCubit, VisitState>(
              bloc: visitCubit,
              builder: (context, visitState) {
                final photos = _photosForStop(visitState, stop.id);

                return Column(
                  children: [
                    const OfflineBanner(margin: EdgeInsets.zero),

                    // Segment 1: Depot Header Card
                    _Staggered(
                      controller: _entranceController,
                      begin: 0.0,
                      end: 0.55,
                      child: BlocBuilder<LocationTrackingCubit,
                          LocationTrackingState>(
                        bloc: locationCubit,
                        builder: (context, locationState) =>
                            _UnifiedDepotHeader(
                          stop: stop,
                          reading: _readLocation(stop, locationState),
                        ),
                      ),
                    ),

                    // Segment 2: Interactive Real-time Map Viewport.
                    //
                    // Deliberately **not** inside `_Staggered`: animating
                    // opacity or transform over a native map view forces
                    // expensive compositing on iOS and makes the map flash
                    // grey. It gets its own builder that fires only when the
                    // rep's position actually changes.
                    Expanded(
                      flex: 4,
                      child: RepaintBoundary(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: BlocBuilder<LocationTrackingCubit,
                                  LocationTrackingState>(
                                bloc: locationCubit,
                                buildWhen: (previous, current) =>
                                    previous.current != current.current,
                                builder: (context, locationState) => TransitMap(
                                  target: stop,
                                  currentPosition:
                                      _mapPosition(stop, locationState),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 14,
                              top: 14,
                              child: _MapExpandButton(
                                onTap: () => _expandMap(context, stop),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Segment 3: Workspace Action Board
                    Expanded(
                      flex: 5,
                      child: _Staggered(
                        controller: _entranceController,
                        begin: 0.18,
                        end: 0.85,
                        offset: 0.10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 16,
                                offset: const Offset(0, -6),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 12),
                              children: [
                                BlocBuilder<LocationTrackingCubit,
                                    LocationTrackingState>(
                                  bloc: locationCubit,
                                  builder: (context, locationState) {
                                    final reading =
                                        _readLocation(stop, locationState);
                                    return _GeoStatusBanner(
                                      reading: reading,
                                      blockedReason: blockedReason,
                                      warnings: warnings,
                                      onAction: () =>
                                          _onLocationAction(reading.phase),
                                    );
                                  },
                                ),
                                SizedBox(height: context.rh(18)),
                                Row(
                                  children: [
                                    Text(
                                      'my_visits.flow.proof_photo'.tr,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: context.rsp(14),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      transitionBuilder: (child, a) =>
                                          ScaleTransition(
                                              scale: a, child: child),
                                      child: photos.isEmpty
                                          ? _PulseIndicator()
                                          : Icon(
                                              Icons.check_circle_rounded,
                                              key: const ValueKey('done'),
                                              color: colors.success,
                                              size: context.rr(18),
                                            ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: context.rh(12)),
                                _CameraDropzone(
                                  photos: photos,
                                  capturing: _capturing,
                                  isLocked: false,
                                  onTap: () => _capture(stop),
                                ),
                                SizedBox(height: context.rh(10)),
                                Text(
                                  'my_visits.flow.checkin_explainer'.tr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: context.rsp(11.5),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Contextual Bottom CTA
                    _Staggered(
                      controller: _entranceController,
                      begin: 0.35,
                      end: 1.0,
                      offset: 0.35,
                      child: _CheckInBottomBar(
                        enabled: !_submitting,
                        submitting: _submitting,
                        hint: blockedReason,
                        onTap: () => unawaited(_submit(stop)),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// What the page renders from the bloc — and nothing else. GPS-driven
  /// fields (distance, accuracy, rep position) are deliberately left out;
  /// the location builders inside handle those.
  Object? _pageKey(ActiveRouteState state) {
    if (state is! ActiveRouteReady) return state.runtimeType;
    final live = _liveStop(state, _stopId);
    return (
      state.currentStopIndex,
      live?.id,
      live?.status,
      state.blockedCheckInReason,
      state.checkInSaveFailed,
      state.checkInWarnings.join('\n'),
    );
  }
}
