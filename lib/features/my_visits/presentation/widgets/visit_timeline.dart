import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_visit_data.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class TimelineEntry {
  const TimelineEntry(
      {required this.time, required this.label, required this.icon});
  final DateTime time;
  final String label;
  final IconData icon;
}

/// Assembles the "08:01 Start Route -> 08:35 Arrived -> Check In -> Stock
/// Updated -> Order Created -> Check Out" style timeline from a stop's
/// check-in/out timestamps plus whatever's been captured during the visit.
List<TimelineEntry> buildVisitTimeline(RouteStop stop, VisitData? data) {
  final entries = <TimelineEntry>[];
  if (stop.actualArrival != null) {
    entries.add(TimelineEntry(
        time: stop.actualArrival!,
        label: 'my_visits.history.checked_in'.tr,
        icon: Icons.login_rounded));
  }
  if (data != null) {
    for (final line in data.orderLines) {
      entries.add(TimelineEntry(
          time: stop.actualArrival ?? DateTime.now(),
          label: 'my_visits.timeline.order'
              .trParams({'product': line.productName}),
          icon: Icons.shopping_cart_rounded));
    }
    for (final s in data.stockUpdates) {
      entries.add(TimelineEntry(
          time: stop.actualArrival ?? DateTime.now(),
          label: 'my_visits.timeline.stock_updated'
              .trParams({'product': s.productName}),
          icon: Icons.inventory_2_rounded));
    }
    for (final r in data.returns) {
      entries.add(TimelineEntry(
          time: stop.actualArrival ?? DateTime.now(),
          label:
              'my_visits.timeline.return'.trParams({'product': r.productName}),
          icon: Icons.undo_rounded));
    }
    for (final c in data.collections) {
      entries.add(TimelineEntry(
          time: stop.actualArrival ?? DateTime.now(),
          label: 'my_visits.timeline.collection'
              .trParams({'amount': c.amount.toStringAsFixed(2)}),
          icon: Icons.payments_rounded));
    }
    for (final n in data.notes) {
      entries.add(TimelineEntry(
          time: n.createdAt,
          label: 'my_visits.timeline.note_added'.tr,
          icon: Icons.note_alt_rounded));
    }
    for (final p in data.photos) {
      entries.add(TimelineEntry(
          time: p.takenAt,
          label: p.isSignature
              ? 'my_visits.timeline.signature_captured'.tr
              : 'my_visits.timeline.photo_added'.tr,
          icon: Icons.photo_camera_rounded));
    }
  }
  if (stop.actualDeparture != null) {
    entries.add(TimelineEntry(
        time: stop.actualDeparture!,
        label: 'my_visits.history.checked_out'.tr,
        icon: Icons.logout_rounded));
  }
  entries.sort((a, b) => a.time.compareTo(b.time));
  return entries;
}

class VisitTimeline extends StatelessWidget {
  const VisitTimeline({super.key, required this.entries});
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    if (entries.isEmpty) {
      return Text('common.no_activity_yet'.tr,
          style: TextStyle(
              color: colors.textSecondary, fontSize: context.rsp(12.5)));
    }
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: context.rh(28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: colors.surfaceStrong,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(entry.icon,
                      size: context.rr(14), color: scheme.primary),
                ),
                SizedBox(width: context.rw(10)),
                Expanded(
                  child: Text(entry.label,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(12.5),
                          fontWeight: FontWeight.w600)),
                ),
                Text(_formatTime(entry.time),
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(11))),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
