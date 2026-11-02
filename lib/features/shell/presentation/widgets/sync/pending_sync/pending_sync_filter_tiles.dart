import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Which kind of saved work the Sync Center lists.
enum PendingSyncFilter { all, depots, visits, quotations }

/// Counts per kind of saved work, doubling as the list's filter.
///
/// A horizontal row of count tiles (All / Depots / Visits / Quotations).
class PendingSyncFilterTiles extends StatelessWidget {
  const PendingSyncFilterTiles({
    super.key,
    required this.selected,
    required this.total,
    required this.counts,
    required this.onSelect,
  });

  final PendingSyncFilter selected;
  final int total;
  final Map<PendingSyncFilter, int> counts;
  final ValueChanged<PendingSyncFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        PendingSyncFilter.all,
        Icons.all_inbox_rounded,
        'sync_center.filter.all'.tr,
        total
      ),
      (
        PendingSyncFilter.depots,
        Icons.storefront_rounded,
        'sync_center.filter.depots'.tr,
        counts[PendingSyncFilter.depots] ?? 0
      ),
      (
        PendingSyncFilter.visits,
        Icons.location_on_rounded,
        'sync_center.filter.visits'.tr,
        counts[PendingSyncFilter.visits] ?? 0
      ),
      (
        PendingSyncFilter.quotations,
        Icons.request_quote_rounded,
        'sync_center.filter.quotations'.tr,
        counts[PendingSyncFilter.quotations] ?? 0
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, (filter, icon, label, count)) in tiles.indexed) ...[
            if (i > 0) SizedBox(width: context.rw(8)),
            _FilterTile(
              icon: icon,
              label: label,
              count: count,
              selected: filter == selected,
              onTap: () => onSelect(filter),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 76),
          padding: EdgeInsets.symmetric(
            horizontal: context.rw(12),
            vertical: context.rh(8),
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : colors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: context.rr(15),
                      color: selected ? fg : scheme.primary),
                  SizedBox(width: context.rw(6)),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: fg,
                      fontSize: context.rsp(16),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? fg : colors.textSecondary,
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
