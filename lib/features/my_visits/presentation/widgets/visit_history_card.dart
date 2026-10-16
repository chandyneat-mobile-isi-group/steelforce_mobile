import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/models/visit_record.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/visit_map_preview.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

(String label, Color color) statusStyle(
        BuildContext context, VisitHistoryStatus status) =>
    switch (status) {
      VisitHistoryStatus.completed => (
          'my_visits.history.status_completed'.tr,
          context.appColors.success
        ),
      VisitHistoryStatus.missed => (
          'my_visits.history.status_missed'.tr,
          Theme.of(context).colorScheme.error
        ),
      VisitHistoryStatus.pending => (
          'my_visits.history.status_pending'.tr,
          context.appColors.warning
        ),
    };

/// One row in the My Visits history list — static map thumbnail, depot
/// name/address, date, and a status chip. Tapping opens the detail screen.
class VisitHistoryCard extends StatelessWidget {
  const VisitHistoryCard({super.key, required this.visit, required this.onTap});

  final VisitRecord visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = statusStyle(context, visit.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: VisitMapPreview(
                    latitude: visit.latitude,
                    longitude: visit.longitude,
                    height: 100,
                    borderRadius: 0,
                    showCoordinates: false,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(context.rr(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.localized(visit.displayName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: context.rsp(14),
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          SizedBox(width: context.rw(8)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: context.rsp(11),
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.rh(4)),
                      Text(
                        visit.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(12)),
                      ),
                      SizedBox(height: context.rh(8)),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: context.rr(13),
                              color: colors.textSecondary),
                          SizedBox(width: context.rw(6)),
                          Text(
                            DateFormat('MMM d, y · h:mm a')
                                .format(visit.visitDate),
                            style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: context.rsp(12)),
                          ),
                          const Spacer(),
                          if (visit.orderPlaced)
                            Icon(Icons.receipt_long_rounded,
                                size: context.rr(16), color: scheme.primary),
                          Icon(Icons.chevron_right_rounded,
                              color: colors.textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
