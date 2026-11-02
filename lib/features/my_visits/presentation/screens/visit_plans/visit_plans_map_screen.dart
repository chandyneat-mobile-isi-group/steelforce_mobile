import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/permissions/location_permission_service.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plans_map_panel.dart';

/// Phnom Penh: where the camera starts while no visit has a location.
const LatLng _kDefaultCenter = LatLng(11.5564, 104.9282);

/// The picked day's visits on a map.
///
/// `GET /api/v1/mobile/plans` sends no outlet coordinates yet, so there are no
/// pins: the map shows where the rep is, a notice says locations are coming,
/// and the day's visits are listed under it. When the backend adds a location
/// to each plan, pins go on this map and nothing else about the screen moves.
class VisitPlansMapScreen extends StatefulWidget {
  const VisitPlansMapScreen({
    super.key,
    required this.plans,
    required this.date,
    @visibleForTesting this.mapBuilder,
  });

  /// The same visits the list is showing, so the two cannot disagree.
  final List<VisitPlan> plans;
  final DateTime date;

  /// Replaces the native map in widget tests, which have no platform view.
  final WidgetBuilder? mapBuilder;

  @override
  State<VisitPlansMapScreen> createState() => _VisitPlansMapScreenState();
}

class _VisitPlansMapScreenState extends State<VisitPlansMapScreen> {
  GoogleMapController? _controller;

  /// `myLocationEnabled` assumes the permission is already held and breaks the
  /// map's platform view on Android when it is not — so check, never ask.
  bool _canShowMyLocation = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveLocationPermission());
  }

  Future<void> _resolveLocationPermission() async {
    if (!sl.isRegistered<LocationPermissionService>()) return;
    final status = await sl<LocationPermissionService>().status();
    if (!mounted || !status.isGranted) return;
    setState(() => _canShowMyLocation = true);
  }

  /// Releases the native view; a leaked one keeps painting over the next screen.
  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final day = DateFormat('EEEE, d MMM yyyy', context.languageCode)
        .format(widget.date);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme:
            IconThemeData(color: colors.textPrimary, size: context.rr(22)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'my_visits.plans.map.title'.tr,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(day,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(12))),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: widget.mapBuilder?.call(context) ??
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(
                            target: _kDefaultCenter, zoom: 11),
                        onMapCreated: (c) => _controller = c,
                        myLocationEnabled: _canShowMyLocation,
                        myLocationButtonEnabled: _canShowMyLocation,
                        zoomControlsEnabled: false,
                      ),
                ),
                Positioned(
                  left: context.rw(12),
                  right: context.rw(12),
                  top: context.rh(12),
                  child: const VisitPlansMapNotice(),
                ),
              ],
            ),
          ),
          VisitPlansMapPanel(plans: widget.plans),
        ],
      ),
    );
  }
}
