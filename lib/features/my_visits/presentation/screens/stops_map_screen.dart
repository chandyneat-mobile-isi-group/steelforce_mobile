import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/permissions/location_permission_service.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/presentation/models/today_stop.dart';
import 'package:steelforce/features/my_visits/presentation/services/navigation_launcher_service.dart';

/// Every stop on the selected day, on one full-screen map.
///
/// The stop list answers "what is next"; this answers "where is my day". They
/// are different questions — a rep deciding whether to double back has to see
/// the shops in relation to each other, which a nearest-first list cannot show.
///
/// Renders the **same** stops the dashboard is showing, passed in rather than
/// re-queried, so the map and the list can never disagree about the day.
class StopsMapScreen extends StatefulWidget {
  const StopsMapScreen({
    super.key,
    required this.stops,
    required this.selectedDate,
  });

  final List<TodayStop> stops;
  final DateTime selectedDate;

  @override
  State<StopsMapScreen> createState() => _StopsMapScreenState();
}

class _StopsMapScreenState extends State<StopsMapScreen> {
  GoogleMapController? _controller;

  /// Whether the blue "you are here" dot may be drawn.
  ///
  /// `myLocationEnabled: true` is not a request — the plugin assumes the
  /// permission is already held and throws a `PlatformException` on Android
  /// when it is not, which kills the map's platform view and leaves a blank
  /// panel. `TransitMap` gets away with the same line only because the
  /// check-in screen has already asked; this screen is reachable straight from
  /// the calendar, so it has to check for itself.
  ///
  /// Read-only: opening a map is not a moment to spring a system prompt on a
  /// rep. Without the permission the pins still render, only the dot is
  /// missing.
  bool _canShowMyLocation = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveLocationPermission());
  }

  Future<void> _resolveLocationPermission() async {
    final status = await sl<LocationPermissionService>().status();
    if (!mounted || !status.isGranted) return;
    setState(() => _canShowMyLocation = true);
  }

  /// Stops with a real pin.
  ///
  /// `(0, 0)` is the app-wide encoding for "no GPS fix was ever captured" — a
  /// real point in the Gulf of Guinea, ~10 000 km away. Plotting one would drag
  /// the camera bounds across the Atlantic and shrink every genuine pin to a
  /// speck, so unmapped shops are excluded and counted instead.
  late final List<TodayStop> _mappable = [
    for (final s in widget.stops)
      if (s.stop.depot.hasCoordinates) s,
  ];

  int get _unmappedCount => widget.stops.length - _mappable.length;

  /// Releases the native map view.
  ///
  /// `GoogleMapController` owns a platform view the engine composites *above*
  /// the Flutter layer. Dropping the Dart reference without disposing leaves
  /// that surface alive and painting over whatever screen is now on top — the
  /// stray white rectangle `TransitMap` documents. Not optional.
  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  /// Frames every pin at once. With a single stop there are no bounds to fit,
  /// so it zooms to the pin instead — `newLatLngBounds` on a zero-area box
  /// gives an unusable zoom level.
  void _fitAll() {
    final controller = _controller;
    if (controller == null || _mappable.isEmpty) return;

    if (_mappable.length == 1) {
      final only = _mappable.first.stop.depot;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(only.latitude, only.longitude), 15),
      );
      return;
    }

    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final s in _mappable) {
      minLat = min(minLat, s.stop.depot.latitude);
      maxLat = max(maxLat, s.stop.depot.latitude);
      minLng = min(minLng, s.stop.depot.longitude);
      maxLng = max(maxLng, s.stop.depot.longitude);
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        // Generous padding: the pins carry callouts, and a marker flush
        // against the edge cannot open one.
        72,
      ),
    );
  }

  /// Pin colour carries the stop's state, so the day reads at a glance:
  /// what is done, what is in progress, what is still owed.
  double _hueFor(VisitStatus status) => switch (status) {
        VisitStatus.checkedOut => BitmapDescriptor.hueGreen,
        VisitStatus.checkedIn => BitmapDescriptor.hueAzure,
        VisitStatus.missed => BitmapDescriptor.hueRed,
        _ => BitmapDescriptor.hueViolet,
      };

  @override
  Widget build(BuildContext context) => LocalizedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final markers = <Marker>{
      for (final todayStop in _mappable)
        Marker(
          markerId: MarkerId(todayStop.stop.id),
          position: LatLng(
            todayStop.stop.depot.latitude,
            todayStop.stop.depot.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _hueFor(todayStop.stop.status)),
          infoWindow: InfoWindow(
            title: context.localized(todayStop.stop.depot.displayName),
            snippet: todayStop.stop.depot.address,
            // Tapping the callout hands the shop to the device's map app for
            // turn-by-turn. Never a bare tap on the marker, which would fire
            // an app switch every time a rep brushed the map while panning.
            onTap: () => openDrivingDirections(
              latitude: todayStop.stop.depot.latitude,
              longitude: todayStop.stop.depot.longitude,
            ),
          ),
        ),
    };

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme:
            IconThemeData(color: colors.textPrimary, size: context.rr(22)),
        title: Text(
          'my_visits.stops_map.title'.tr,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _mappable.isEmpty
          ? _MapEmptyState(hasStops: widget.stops.isNotEmpty)
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _mappable.first.stop.depot.latitude,
                      _mappable.first.stop.depot.longitude,
                    ),
                    zoom: 12,
                  ),
                  onMapCreated: (controller) {
                    _controller = controller;
                    // After the first frame: the map has no size until it is
                    // laid out, and fitting bounds to a zero-size viewport is
                    // silently ignored.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _fitAll());
                  },
                  markers: markers,
                  myLocationEnabled: _canShowMyLocation,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  left: context.rw(12),
                  right: context.rw(12),
                  top: context.rh(12),
                  child: _MapLegend(
                    mappedCount: _mappable.length,
                    unmappedCount: _unmappedCount,
                  ),
                ),
                Positioned(
                  right: context.rw(12),
                  bottom: context.rh(20),
                  child: FloatingActionButton.small(
                    heroTag: 'stops_map_fit_all',
                    backgroundColor: scheme.primary,
                    tooltip: 'my_visits.stops_map.fit_all'.tr,
                    onPressed: _fitAll,
                    child: Icon(Icons.center_focus_strong_rounded,
                        color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Says how many stops are on the map and, honestly, how many are not.
///
/// A shop with no recorded pin is invisible here, and a rep who counts eight
/// cards and six markers needs to know why — silence would read as a bug in
/// the map rather than missing data on the shop.
class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.mappedCount, required this.unmappedCount});

  final int mappedCount;
  final int unmappedCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(14), vertical: context.rh(10)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'my_visits.stops_map.count'.trParams({'count': '$mappedCount'}),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(13),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (unmappedCount > 0) ...[
            SizedBox(height: context.rh(4)),
            Text(
              'my_visits.stops_map.unmapped'
                  .trParams({'count': '$unmappedCount'}),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(11.5),
              ),
            ),
          ],
          SizedBox(height: context.rh(8)),
          Wrap(
            spacing: context.rw(10),
            runSpacing: context.rh(4),
            children: [
              _LegendDot(
                  color: Colors.deepPurple,
                  label: 'my_visits.stops_map.legend_pending'.tr),
              _LegendDot(
                  color: Colors.blue,
                  label: 'my_visits.stops_map.legend_in_progress'.tr),
              _LegendDot(
                  color: Colors.green,
                  label: 'my_visits.stops_map.legend_visited'.tr),
              _LegendDot(
                  color: Colors.red,
                  label: 'my_visits.stops_map.legend_skipped'.tr),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.rr(8),
          height: context.rr(8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: context.rw(4)),
        Text(
          label,
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: context.rsp(11),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Two genuinely different empty states, said differently: a day with no stops
/// at all, and a day whose stops have no recorded pins.
class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.hasStops});
  final bool hasStops;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasStops ? Icons.wrong_location_outlined : Icons.map_outlined,
              size: context.rw(40),
              color: colors.textHint,
            ),
            SizedBox(height: context.rh(12)),
            Text(
              hasStops
                  ? 'my_visits.stops_map.no_pins'.tr
                  : 'my_visits.stops_map.no_stops'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              hasStops
                  ? 'my_visits.stops_map.no_pins_hint'.tr
                  : 'my_visits.stops_map.no_stops_hint'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: context.rsp(12)),
            ),
          ],
        ),
      ),
    );
  }
}
