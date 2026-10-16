import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// One removable summary chip describing an active filter facet.
class FilterChipData {
  const FilterChipData({required this.label, required this.onClear});

  /// Human-readable summary, e.g. "Size: 12mm" or "Grade: SD390".
  final String label;

  /// Removes just this facet from the active filter.
  final VoidCallback onClear;
}

/// Horizontal, scrollable summary of the active filters with a leading
/// counter badge and a trailing "Clear all". Each chip clears exactly one
/// facet. Renders nothing when there are no active filters, so callers can
/// drop it into a column unconditionally.
class ActiveFilterChipsBar extends StatelessWidget {
  const ActiveFilterChipsBar({
    super.key,
    required this.chips,
    required this.onClearAll,
  });

  final List<FilterChipData> chips;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: context.rh(36),
      child: Row(
        children: [
          _CounterBadge(count: chips.length),
          SizedBox(width: context.rw(8)),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => SizedBox(width: context.rw(8)),
              itemBuilder: (context, index) =>
                  _RemovableChip(data: chips[index]),
            ),
          ),
          SizedBox(width: context.rw(4)),
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: Text('common.clear_all'.tr),
          ),
        ],
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: context.rh(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
      child: Text(
        '$count',
        style: TextStyle(
            color: Colors.white,
            fontSize: context.rsp(12),
            fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.data});
  final FilterChipData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHighest
            : context.appColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: context.rsp(12.5),
                fontWeight: FontWeight.w700),
          ),
          SizedBox(width: context.rw(2)),
          InkWell(
            onTap: data.onClear,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.all(context.rr(4)),
              child: Icon(
                Icons.close_rounded,
                size: context.rr(14),
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
