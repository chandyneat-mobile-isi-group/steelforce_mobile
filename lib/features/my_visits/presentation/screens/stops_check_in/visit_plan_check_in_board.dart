part of '../stops_check_in_screen.dart';

/// The action board of [VisitPlanCheckInScreen]: location banner, proof
/// photos and, outside the zone, the reason form — as on the route page.
extension _VisitPlanCheckInBoard on _VisitPlanCheckInState {
  Widget _board(BuildContext context, PlanCheckInState state, RouteStop stop,
      List<VisitPhoto> photos) {
    final colors = context.appColors;
    final editable = state.stage == PlanCheckInStage.ready;
    return _Staggered(
      controller: _entranceController,
      begin: 0.18,
      end: 0.85,
      offset: 0.10,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -6),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              BlocBuilder<LocationTrackingCubit, LocationTrackingState>(
                builder: (context, ls) {
                  final reading = _read(stop, ls);
                  return _GeoStatusBanner(
                    reading: reading,
                    blockedReason: null,
                    warnings: const [],
                    onAction: () => _onLocationAction(reading.phase),
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
                  photos.isEmpty
                      ? _PulseIndicator()
                      : Icon(Icons.check_circle_rounded,
                          color: colors.success, size: context.rr(18)),
                ],
              ),
              SizedBox(height: context.rh(12)),
              _CameraDropzone(
                photos: photos,
                capturing: _capturing,
                isLocked: !editable || !state.canAddPhoto,
                onTap: () => unawaited(_capture(stop)),
              ),
              SizedBox(height: context.rh(18)),
              PlanCheckInNotesField(controller: _notes, enabled: editable),
              SizedBox(height: context.rh(6)),
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
    );
  }
}
