part of '../stops_check_in_screen.dart';

/// Check-in for a Visit Plan on the route check-in UI — the same header, map,
/// location banner, photo dropzone and button — sent through the Plans API
/// (`POST /api/v1/mobile/plans/{id}/check-in`) by [PlanCheckInCubit].
///
/// Expects a [PlanCheckInCubit] and a [LocationTrackingCubit] above it. Pops
/// `true` once the server has the check-in.
class VisitPlanCheckInScreen extends StatefulWidget {
  const VisitPlanCheckInScreen({super.key, required this.plan});

  static const String routeName = 'visit-plan-check-in';

  final VisitPlan plan;

  @override
  State<VisitPlanCheckInScreen> createState() => _VisitPlanCheckInState();
}

class _VisitPlanCheckInState extends State<VisitPlanCheckInScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entranceController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 780));
  late final LocationTrackingCubit _location =
      context.read<LocationTrackingCubit>();
  final _notes = TextEditingController();
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceController.forward();
    // A 10 m filter, as on the route check-in: the last metres matter.
    unawaited(_location.observeForScreen(distanceFilterMeters: 10));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_location.stopObserving());
    _entranceController.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Back from Settings with Location switched on: search again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed || !mounted) return;
    final status = _location.state.fixStatus;
    if (status == GpsFixStatus.servicesDisabled ||
        status == GpsFixStatus.permissionDenied ||
        status == GpsFixStatus.permissionDeniedForever ||
        status == GpsFixStatus.unavailable) {
      unawaited(_location.retryFix());
    }
  }

  /// The plan as the route UI's stop: name, code, and the depot pin and
  /// radius the server measures against.
  RouteStop _stopFor(PlanCheckInTarget? target) {
    final plan = widget.plan;
    return RouteStop(
      id: plan.id,
      routeId: '',
      sequence: 0,
      plannedArrival: null,
      plannedDeparture: null,
      status: VisitStatus.pending,
      depot: DepotStopInfo(
        id: plan.depotCode ?? plan.id,
        name: target?.depotName ?? plan.displayName ?? '',
        code: plan.depotCode ?? '',
        contact: '',
        phone: '',
        address: plan.depotCode ?? '',
        territory: plan.territoryCode ?? '',
        territoryType: TerritoryType.urban,
        latitude: target?.depotLatitude ?? plan.latitude ?? 0,
        longitude: target?.depotLongitude ?? plan.longitude ?? 0,
        geofenceRadiusOverride: target?.radiusMeters,
      ),
    );
  }

  /// The rep's position for both the reading and the check-in.
  LocationSample? _fix(RouteStop stop, LocationTrackingState locationState) =>
      kUseStaticCheckInPosition
          ? _staticMapSample(stop)
          : locationState.usableFix();

  /// The same verdict the route check-in shows, against the plan's depot.
  CheckInReading _read(RouteStop stop, LocationTrackingState locationState) {
    final sample = _fix(stop, locationState);
    final depot = stop.depot;
    final radius =
        depot.geofenceRadiusOverride ?? _outletLocations.radiusMeters;
    final accuracy = sample?.accuracyMeters ?? 0.0;
    final verdict = CheckInLocationVerifier.verify(
      outlet: depot.hasCoordinates
          ? OutletLocation(
              latitude: depot.latitude,
              longitude: depot.longitude,
              radiusMeters: radius)
          : null,
      deviceLatitude: sample?.latitude,
      deviceLongitude: sample?.longitude,
      fallbackRadiusMeters: radius,
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

  void _onLocationAction(CheckInGpsPhase phase) {
    HapticFeedback.selectionClick();
    unawaited(phase.isBlockedBySetting
        ? _location.openSettingsForStatus()
        : _location.retryFix());
  }

  Future<void> _capture(RouteStop stop) async {
    if (_capturing) return;
    HapticFeedback.mediumImpact();
    final cubit = context.read<PlanCheckInCubit>();
    final pos = _location.state.current;
    setState(() => _capturing = true);
    try {
      final result = await sl<ProofPhotoService>().captureStamped(
        latitude: pos?.latitude ?? stop.depot.latitude,
        longitude: pos?.longitude ?? stop.depot.longitude,
      );
      if (result != null) cubit.addPhoto(result.filePath);
    } catch (e, stack) {
      debugPrintStack(
          label: 'planCheckIn.capture failed: $e', stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('my_visits.stop_info.photo_failed'.tr)));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final cubit = context.read<PlanCheckInCubit>();
    // Within the zone it simply checks in. Outside it — the fix beyond the
    // radius, or the server saying so — a reason is asked for first.
    PlanCheckInReason? reason;
    if (cubit.state.needsReason) {
      reason = await _askReason(cubit.state);
      if (reason == null) return;
    }
    var done = await cubit.submit(reason: reason, notes: _notes.text);
    if (!done && reason == null && cubit.state.needsReason && mounted) {
      reason = await _askReason(cubit.state);
      if (reason == null) return;
      done = await cubit.submit(reason: reason, notes: _notes.text);
    }
    // The result says whether it went now or waits on the device.
    if (done && mounted) Navigator.of(context).pop(cubit.state.result);
  }

  Future<PlanCheckInReason?> _askReason(PlanCheckInState s) async {
    if (!mounted) return null;
    return showPlanCheckInReasonSheet(
      context,
      distanceMeters: s.distanceMeters,
      radiusMeters:
          s.target?.zoneRadiusMeters ?? PlanCheckInTarget.defaultRadiusMeters,
    );
  }

  /// Why the button is off, or null when the check-in can be sent.
  String? _hint(PlanCheckInState s) {
    String t(String key) => 'my_visits.plans.check_in.hint.$key'.tr;
    if (s.fix == null) return t('location');
    if (s.photos.isEmpty) return t('photo');
    return null;
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(builder: _buildPage);
}
