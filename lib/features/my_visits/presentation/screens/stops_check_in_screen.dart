import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/platform/storage/local_files.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/offline_banner.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_policy.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/proof_photo_service.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/events/active_route_event.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/location_tracking_state.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_state.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_inventory_survey.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/visit_step_bar.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/stop_information_screen.dart';
import 'package:steelforce/features/my_visits/domain/services/check_in_location_verifier.dart';
import 'package:steelforce/features/my_visits/domain/services/outlet_location_source.dart';
import 'package:steelforce/features/my_visits/presentation/models/check_in_gps_phase.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/check_in_confirmation_dialog.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/remote_check_in_sheet.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/transit_map.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/painters/dashed_rrect.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';

part 'stops_check_in/check_in_screen_support.dart';
part 'stops_check_in/check_in_location_bridge.dart';
part 'stops_check_in/check_in_submit_flow.dart';
part 'stops_check_in/check_in_page.dart';
part 'stops_check_in/check_in_header.dart';
part 'stops_check_in/check_in_geo_status_banner.dart';
part 'stops_check_in/check_in_proof_photo.dart';
part 'stops_check_in/check_in_bottom_bar.dart';
part 'stops_check_in/check_in_map_controls.dart';

/// Forces the geo-status banner to read "inside geofence" regardless of the
/// real verdict.
///
/// **Now false, and it should stay false.** It was `true`, and it was OR'd
/// into the *banner* only — the bloc read `state.insideGeofence` directly and
/// never saw it. So the screen showed green while the bloc refused the
/// check-in, which is why this failed silently for so long: the one indicator
/// a rep could see was wired to a constant.
///
/// Nothing depends on it any more. A device with no fix, or a shop with no
/// recorded pin, now checks in and records itself unverified
/// (`ActiveRouteBloc._onCheckIn`) instead of needing the banner to lie on its
/// behalf.
const bool kDebugForceInsideGeofence = false;

class RouteCheckInScreen extends StatefulWidget {
  const RouteCheckInScreen({
    super.key,
    this.stop,
  });

  final RouteStop? stop;

  @override
  State<RouteCheckInScreen> createState() => _RouteCheckInScreenState();
}

class _RouteCheckInScreenState extends State<RouteCheckInScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _capturing = false;

  /// True between dispatching `CheckInRequested` and the bloc answering.
  /// Drives the CTA's spinner and gates `_onCheckInSettled`, so a state change
  /// caused by anything else (a GPS fix, a photo) cannot navigate on its own.
  bool _submitting = false;

  /// The bloc's `checkInAttempt` when this screen dispatched. The answer is
  /// the first state whose counter is higher — never "any state change",
  /// which a GPS update would also be.
  int? _awaitingAttempt;

  /// Releases the spinner if the bloc never answers (not loaded, a handler
  /// still busy with an earlier attempt). Nothing on this screen may spin
  /// forever.
  Timer? _submitWatchdog;

  /// Drives the staggered entrance: header → map → action board → CTA, each
  /// fading and rising on its own slice of one timeline.
  late AnimationController _entranceController;

  /// The id of the stop this screen checks in to.
  String? get _stopId => widget.stop?.id ?? _currentStop()?.id;

  /// Marks the start of a check-in attempt: spinner on, answer awaited,
  /// watchdog armed.
  void _beginSubmit(ActiveRouteBloc bloc) {
    final state = bloc.state;
    _awaitingAttempt = state is ActiveRouteReady ? state.checkInAttempt : -1;
    _submitWatchdog?.cancel();
    _submitWatchdog = Timer(_submitTimeout, _onSubmitTimeout);
    setState(() => _submitting = true);
  }

  void _endSubmit() {
    _submitWatchdog?.cancel();
    _submitWatchdog = null;
    _awaitingAttempt = null;
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );

    final initialStop = widget.stop;
    if (initialStop != null) {
      _resolveBloc<VisitCubit>(context).load(initialStop.id);
      // Without this the bloc never learns which stop this is, and every
      // check-in from this entry point is silently discarded.
      unawaited(_ensureStopSelected(initialStop));
    } else {
      final activeRouteBloc = _resolveBloc<ActiveRouteBloc>(context);
      final state = activeRouteBloc.state;
      if (state is ActiveRouteReady && state.hasCurrentStop) {
        _resolveBloc<VisitCubit>(context)
            .load(state.route.stops[state.currentStopIndex].id);
      }
    }

    // Start reading the GPS. Nothing else does.
    //
    // This screen used to assume the tracker "is started well before this
    // screen opens" — nothing ever called `start` or `observeForScreen`, so
    // `LocationTrackingState.current` was permanently null. The consequence was
    // quiet and total: `_reportGeofence` returned early on every sample, so
    // `GeofenceStatusChanged` was never dispatched, `insideGeofence` kept its
    // optimistic default, and the check-in that claims to verify where a rep is
    // standing never read the device at all.
    //
    // Screen-scoped (`observeForScreen`), not the route stream: this needs a
    // position while the rep is looking at the screen, and a foreground service
    // with a persistent notification is not the right price for that. A running
    // route's own `start` is independent and unaffected.
    unawaited(_beginObservingLocation());

    _entranceController.forward();
  }

  @override
  void dispose() {
    // Released here rather than left running: the position was for this screen.
    // A route-scoped `start` is a separate subscription and keeps going.
    WidgetsBinding.instance.removeObserver(this);
    _submitWatchdog?.cancel();
    unawaited(_resolveBloc<LocationTrackingCubit>(context).stopObserving());
    _entranceController.dispose();
    super.dispose();
  }

  /// Coming back from system Settings (Location switched on, permission
  /// granted) re-runs the search on its own. Without this the rep fixes the
  /// setting, returns, and the screen still says Location is off.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed || !mounted) return;
    final cubit = _resolveBloc<LocationTrackingCubit>(context);
    final status = cubit.state.fixStatus;
    if (status == GpsFixStatus.servicesDisabled ||
        status == GpsFixStatus.permissionDenied ||
        status == GpsFixStatus.permissionDeniedForever ||
        status == GpsFixStatus.unavailable) {
      unawaited(cubit.retryFix());
    }
  }

  Future<void> _capture(RouteStop stop) async {
    if (_capturing) return;

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final pos = _resolveBloc<LocationTrackingCubit>(context).state.current;
    setState(() => _capturing = true);

    try {
      final result = await sl<ProofPhotoService>().captureStamped(
        latitude: pos?.latitude ?? stop.depot.latitude,
        longitude: pos?.longitude ?? stop.depot.longitude,
      );

      if (!mounted) return;

      if (result != null) {
        _resolveBloc<VisitCubit>(context).addPhoto(VisitPhoto(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          stopId: stop.id,
          url: result.filePath,
          caption: 'my_visits.stop.shopfront_proof'.tr,
          takenAt: result.takenAt,
        ));
      }
    } catch (e, stack) {
      // Logged, not shown. A camera or file-system exception names a path and
      // a platform error code — useless to a rep and, per `flutter.md` §3,
      // never what an error state should render.
      debugPrintStack(
          label: 'checkIn.capturePhoto failed: $e', stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('my_visits.stop_info.photo_failed'.tr),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(builder: _build);
}
