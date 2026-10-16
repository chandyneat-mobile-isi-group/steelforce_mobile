import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/services/navigation_launcher_service.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';

/// Focused transit map for Step 2: the live GPS dot, the target shop's marker
/// + geofence circle, and a direct polyline between them. Camera auto-fits
/// both points so the rep always sees "where I am → where I'm going".
class TransitMap extends StatefulWidget {
  const TransitMap({super.key, required this.target, this.currentPosition});

  final RouteStop target;
  final LocationSample? currentPosition;

  @override
  State<TransitMap> createState() => _TransitMapState();
}

class _TransitMapState extends State<TransitMap> {
  GoogleMapController? _controller;
  bool _didInitialFit = false;

  /// Whether the shop has a pin worth drawing anything against.
  ///
  /// `(0, 0)` is the app-wide encoding for "no coordinates were ever recorded",
  /// and a large share of the synced depots carry it. Everything below used to
  /// treat it as a real destination: the marker, the geofence circle and the
  /// polyline were placed in the Gulf of Guinea, and `_fitBounds` then framed a
  /// box from Cambodia to the prime meridian — half the planet, at a zoom where
  /// nothing is legible. That is the "blank grey map" on the check-in screen.
  ///
  /// With no pin there is no destination, so none of those layers are drawn and
  /// the camera simply follows the rep.
  bool get _hasTarget => widget.target.depot.hasCoordinates;

  LatLng get _targetLatLng =>
      LatLng(widget.target.depot.latitude, widget.target.depot.longitude);
  LatLng? get _currentLatLng => widget.currentPosition == null
      ? null
      : LatLng(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);

  /// Releases the native map view.
  ///
  /// `GoogleMapController` owns an Android/iOS platform view — a native surface
  /// the engine composites *above* the Flutter layer, not a widget in the Dart
  /// tree. Dropping the Dart reference without disposing it leaves that surface
  /// alive and registered with the platform-view controller, so it keeps
  /// painting at its last screen-space rect over whatever screen is now on top.
  /// That is the stray rounded white rectangle seen on Home and the Route
  /// Dashboard: it is invisible to any widget-tree audit precisely because it
  /// is not a widget.
  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  /// Hands the target shop to the device's map app for turn-by-turn driving
  /// directions. Reached from the Navigate button and from the destination
  /// marker's info window — never from a bare tap on the map itself, which
  /// would fire an app switch every time a rep panned or zoomed.
  Future<void> _openDirections() async {
    final launched = await openDrivingDirections(
      latitude: widget.target.depot.latitude,
      longitude: widget.target.depot.longitude,
    );
    if (launched || !mounted) return;
    // No map app took it. Say so rather than leave the button looking dead.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('common.generic_error'.tr)),
    );
  }

  @override
  void didUpdateWidget(covariant TransitMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fit both points the first time we get a GPS fix.
    if (!_didInitialFit &&
        widget.currentPosition != null &&
        oldWidget.currentPosition == null) {
      _fitBounds();
    }
  }

  void _fitBounds() {
    final current = _currentLatLng;
    final controller = _controller;
    if (controller == null) return;
    _didInitialFit = true;

    // No pin: there is nothing to fit *to*, so the rep's own position is the
    // only thing worth centring on. Without a fix either, the camera is left
    // wherever it is rather than being sent to (0, 0).
    if (!_hasTarget) {
      if (current != null) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(current, 15));
      }
      return;
    }

    if (current == null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(_targetLatLng, 15));
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(min(current.latitude, _targetLatLng.latitude),
          min(current.longitude, _targetLatLng.longitude)),
      northeast: LatLng(max(current.latitude, _targetLatLng.latitude),
          max(current.longitude, _targetLatLng.longitude)),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _currentLatLng;

    final markers = <Marker>{
      if (_hasTarget)
        Marker(
          markerId: MarkerId(widget.target.id),
          position: _targetLatLng,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: context.localized(widget.target.depot.displayName),
            snippet: widget.target.depot.address,
            // Tapping the shop's callout is the idiom every map app uses for
            // "take me here", so it costs no discovery on top of the button.
            onTap: _openDirections,
          ),
        ),
      if (current != null)
        Marker(
          markerId: const MarkerId('current_position'),
          position: current,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 10,
        ),
    };

    // Only where there is a pin to draw one around. A geofence ring at (0, 0)
    // asserts a check-in area that does not exist.
    final circles = <Circle>{
      if (_hasTarget)
        Circle(
          circleId: const CircleId('geofence'),
          center: _targetLatLng,
          radius: widget.target.depot.geofenceRadiusMeters,
          strokeColor: scheme.primary,
          strokeWidth: 2,
          fillColor: scheme.primary.withValues(alpha: 0.12),
        ),
    };

    final polylines = (current == null || !_hasTarget)
        ? const <Polyline>{}
        : {
            Polyline(
              polylineId: const PolylineId('to_target'),
              color: scheme.primary,
              width: 4,
              patterns: [PatternItem.dash(24), PatternItem.gap(12)],
              points: [current, _targetLatLng],
            ),
          };

    // Nothing to centre on: no pin, and no fix yet. A map opened here would
    // render the Gulf of Guinea, which reads as a broken map rather than as
    // missing data — so say what is actually wrong instead.
    if (!_hasTarget && current == null) {
      return _NoLocationPlaceholder();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: current ?? _targetLatLng,
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _controller = controller;
            WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
          },
          markers: markers,
          circles: circles,
          polylines: polylines,
          // Native OS blue-dot layer — draws straight from the device's GPS,
          // independent of LocationTrackingCubit/current. Useful both as a
          // real "where am I" indicator for the rep and as a way to tell
          // whether a stuck geofence is a tracking-pipeline issue (blue dot
          // moves, custom marker doesn't) or a genuine GPS/position issue
          // (blue dot itself doesn't move or sits outside the circle).
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        // Hidden, not disabled: driving directions to (0, 0) open the device's
        // map app on open water, which is worse than having no button.
        if (_hasTarget)
          Positioned(
            left: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'transit_map_navigate',
              backgroundColor: scheme.primary,
              // Named for screen readers; the icon alone carries no label.
              tooltip: 'my_visits.route_info.action_navigate'.tr,
              onPressed: _openDirections,
              child: Icon(Icons.directions_rounded, color: scheme.onPrimary),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'transit_map_recenter',
            backgroundColor: scheme.primary,
            onPressed: _fitBounds,
            child: Icon(Icons.center_focus_strong_rounded,
                color: scheme.onPrimary),
          ),
        ),
      ],
    );
  }
}

/// Shown in place of the map when the shop has no pin and the device has no
/// fix — the one combination where a map has nothing true to display.
class _NoLocationPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ColoredBox(
      color: colors.surfaceSoft,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rw(28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined,
                  size: context.rw(32), color: colors.textHint),
              SizedBox(height: context.rh(10)),
              Text(
                'my_visits.check_in_verification.no_outlet_title'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(13.5),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: context.rh(4)),
              Text(
                'my_visits.check_in_verification.no_outlet_body'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
