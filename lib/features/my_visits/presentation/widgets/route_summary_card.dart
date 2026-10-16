import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Dashboard route-summary card — one per [RoutePlan]. Answers "which route
/// should I start?" with a glanceable summary only (name, territory, status,
/// progress, stop counts, live distance/ETA, priority), never per-stop detail.
///
/// Pure presentation: every value comes from [RoutePlan]'s own getters or from
/// [GeofenceService] against the passed [currentPosition] — no bloc, no I/O.
/// Tapping opens the Route Information screen (wired by the caller).
///
/// The route name is wrapped in a [Hero] (`route-name-<id>`) so it shares a
/// flight into the Route Information hero header.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.route,
    required this.onTap,
    this.currentPosition,
  });

  final RoutePlan route;
  final VoidCallback onTap;

  /// Live GPS fix, if tracking is active — used to show distance/ETA to the
  /// next unvisited stop. Null falls back to a "--" label.
  final LocationSample? currentPosition;

  /// First stop not yet visited — the route's live "next" target.
  RouteStop? get _nextStop {
    for (final s in route.stops) {
      if (s.status != VisitStatus.checkedOut &&
          s.status != VisitStatus.missed) {
        return s;
      }
    }
    return null;
  }

  double? get _distanceToNextMeters {
    final pos = currentPosition;
    final next = _nextStop;
    if (pos == null || next == null) return null;
    return GeofenceService.distanceMeters(
      pos.latitude,
      pos.longitude,
      next.depot.latitude,
      next.depot.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final status = _statusStyle(context);

    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(12)),
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(18)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(context.rr(18)),
              border: Border.all(color: colors.border, width: 1.w),
              boxShadow: colors.cardShadow,
            ),
            padding: EdgeInsets.fromLTRB(
                context.rw(16), context.rh(14), context.rw(14), context.rh(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row: route name + status pill.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'route-name-${route.id}',
                        flightShuttleBuilder: _titleShuttle,
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            // Key for mock plans, verbatim description for
                            // real SAP ones — `.tr` returns anything it
                            // doesn't recognise unchanged.
                            route.name.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(16),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: context.rw(8)),
                    _Pill(label: status.label, color: status.color),
                  ],
                ),
                SizedBox(height: context.rh(4)),

                // Territory · date subline.
                Text(
                  '${route.territory} · ${DateFormat('EEE, MMM d').format(route.visitDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: context.rsp(12)),
                ),
                SizedBox(height: context.rh(12)),

                // Progress bar + completed/total.
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(context.rr(6)),
                        child: LinearProgressIndicator(
                          value: route.progress,
                          minHeight: context.rh(7),
                          backgroundColor: colors.surfaceStrong,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(scheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(width: context.rw(10)),
                    Text(
                      '${route.completedStops}/${route.totalStops}',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(12),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(12)),

                // Metric chips: stops · remaining · distance/ETA · priority.
                Wrap(
                  spacing: context.rw(8),
                  runSpacing: context.rh(8),
                  children: [
                    _MetricChip(
                      icon: Icons.storefront_rounded,
                      label: 'my_visits.route_info.stops_count'
                          .trParams({'count': route.totalStops}),
                    ),
                    _MetricChip(
                      icon: Icons.pending_actions_rounded,
                      label: 'my_visits.route_info.remaining_count'.trParams(
                          {'count': route.totalStops - route.completedStops}),
                    ),
                    _MetricChip(
                      icon: Icons.navigation_rounded,
                      label: _distanceEtaLabel(),
                    ),
                    _PriorityChip(level: _priority()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _distanceEtaLabel() {
    final meters = _distanceToNextMeters;
    if (meters == null) return 'my_visits.route_info.distance_unknown'.tr;
    final km = meters / 1000;
    final distance =
        km < 0.1 ? '${meters.round()} m' : '${km.toStringAsFixed(1)} km';
    // Same 25 km/h blended field-average used by RouteDashboardCubit.
    final etaMin = ((km / 25) * 60).clamp(1, 999).round();
    return 'my_visits.route_info.distance_eta'
        .trParams({'distance': distance, 'eta': etaMin});
  }

  /// Placeholder priority heuristic until routes carry a real priority field:
  /// a route whose next stop's planned arrival is now/overdue reads as "high".
  _Priority _priority() {
    final next = _nextStop;
    if (next == null) return _Priority.normal;
    // An ad hoc visit has no planned arrival, so it cannot be overdue — there
    // is no time it was supposed to happen by. Skip the check rather than
    // substituting a window the rep never agreed to.
    final plannedArrival = next.plannedArrival;
    if (plannedArrival == null) return _Priority.normal;
    return plannedArrival.isBefore(DateTime.now())
        ? _Priority.high
        : _Priority.normal;
  }

  ({String label, Color color}) _statusStyle(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return switch (route.status) {
      RouteStatus.planned => (
          label: 'my_visits.route_info.status_planned'.tr,
          color: colors.textSecondary
        ),
      RouteStatus.published => (
          label: 'my_visits.route_info.status_published'.tr,
          color: colors.info
        ),
      RouteStatus.inProgress => (
          label: 'my_visits.route_info.status_in_progress'.tr,
          color: scheme.primary
        ),
      RouteStatus.completed => (
          label: 'my_visits.route_info.status_completed'.tr,
          color: colors.success
        ),
    };
  }

  /// Keeps the Hero title legible (not doubled/boxed) mid-flight.
  Widget _titleShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) =>
      DefaultTextStyle(
        style: DefaultTextStyle.of(toHeroContext).style,
        child: toHeroContext.widget,
      );
}

enum _Priority { high, normal }

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.level});
  final _Priority level;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (color, key) = switch (level) {
      _Priority.high => (colors.warning, 'my_visits.route_info.priority_high'),
      _Priority.normal => (
          colors.textSecondary,
          'my_visits.route_info.priority_normal'
        ),
    };
    return _MetricChip(
      icon: Icons.flag_rounded,
      label: key.tr,
      color: color,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fg = color ?? colors.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(10), vertical: context.rh(6)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(10)),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rw(13), color: fg),
          SizedBox(width: context.rw(5)),
          Text(
            label,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(11),
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(10), vertical: context.rh(5)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.rr(20)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: context.rsp(10.5),
            fontWeight: FontWeight.w800),
      ),
    );
  }
}
