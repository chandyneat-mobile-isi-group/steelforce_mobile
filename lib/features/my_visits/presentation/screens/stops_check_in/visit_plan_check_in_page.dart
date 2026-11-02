part of '../stops_check_in_screen.dart';

/// [VisitPlanCheckInScreen]'s layout: the route check-in page, segment for
/// segment, with the plan's reason form under the photo when it needs one.
extension _VisitPlanCheckInPage on _VisitPlanCheckInState {
  Widget _buildPage(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<PlanCheckInCubit>();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          'my_visits.plans.check_in.title'.tr,
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
          // The check-in sends the same fix the banner measures.
          BlocListener<LocationTrackingCubit, LocationTrackingState>(
            listenWhen: (p, c) =>
                p.current != c.current || p.fixStatus != c.fixStatus,
            listener: (context, ls) =>
                cubit.useFix(_fix(_stopFor(cubit.state.target), ls)),
          ),
          BlocListener<PlanCheckInCubit, PlanCheckInState>(
            listenWhen: (p, c) =>
                c.failure != null &&
                p.failure != c.failure &&
                c.stage != PlanCheckInStage.loadFailed,
            listener: (context, s) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(s.failure!.userMessage))),
          ),
        ],
        child: BlocBuilder<PlanCheckInCubit, PlanCheckInState>(
          builder: (context, state) => switch (state.stage) {
            PlanCheckInStage.loading => Center(
                child: CircularProgressIndicator(
                    color: scheme.primary, strokeWidth: 2.8)),
            PlanCheckInStage.loadFailed => VisitPlansMessage(
                icon: Icons.error_outline_rounded,
                title: 'my_visits.plans.check_in.error.load'.tr,
                hint: state.failure?.userMessage ?? 'common.generic_error'.tr,
                actionLabel: 'common.retry'.tr,
                onAction: () =>
                    unawaited(cubit.start(widget.plan.id, locateNow: false)),
                isError: true,
              ),
            _ => _segments(context, state, _stopFor(state.target)),
          },
        ),
      ),
    );
  }

  Widget _segments(
      BuildContext context, PlanCheckInState state, RouteStop stop) {
    final photos = [
      for (final path in state.photos)
        VisitPhoto(
          id: path,
          stopId: stop.id,
          url: path,
          caption: 'my_visits.stop.shopfront_proof'.tr,
          takenAt: DateTime.now(),
        ),
    ];

    return Column(
      children: [
        const OfflineBanner(margin: EdgeInsets.zero),
        _Staggered(
          controller: _entranceController,
          begin: 0.0,
          end: 0.55,
          child: BlocBuilder<LocationTrackingCubit, LocationTrackingState>(
            builder: (context, ls) =>
                _UnifiedDepotHeader(stop: stop, reading: _read(stop, ls)),
          ),
        ),
        // Not staggered, as on the route page: animating over a native map
        // makes it flash grey on iOS.
        Expanded(
          flex: 4,
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      BlocBuilder<LocationTrackingCubit, LocationTrackingState>(
                    buildWhen: (p, c) => p.current != c.current,
                    builder: (context, ls) => TransitMap(
                        target: stop, currentPosition: _mapPosition(stop, ls)),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: _MapExpandButton(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _FullScreenTransitMap(stop: stop))),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(flex: 5, child: _board(context, state, stop, photos)),
        _Staggered(
          controller: _entranceController,
          begin: 0.35,
          end: 1.0,
          offset: 0.35,
          // Rebuilt with the page: picking a reason redraws it.
          child: Builder(
            builder: (context) {
              final submitting = state.stage == PlanCheckInStage.submitting;
              final hint = _hint(state);
              return _CheckInBottomBar(
                enabled: !submitting && hint == null,
                submitting: submitting,
                hint: hint,
                onTap: () => unawaited(_submit()),
              );
            },
          ),
        ),
      ],
    );
  }
}
