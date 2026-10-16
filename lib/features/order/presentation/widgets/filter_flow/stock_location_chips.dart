import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';

/// Narrows the matched SKUs to one stock location.
///
/// Sits above the results rather than inside the guided steps, because that is
/// where the decision actually happens: the rep first finds the material, then
/// decides which plant to quote it from. Answering it as a step would make it
/// invalidate everything below it, which is wrong — location changes *which*
/// SKUs are listed, never *what* the article is.
///
/// Only rendered when there is a real choice; a single location means every
/// matched SKU ships from the same place and the control would do nothing.
class StockLocationChips extends StatelessWidget {
  const StockLocationChips({
    super.key,
    required this.options,
    required this.selectedCode,
    required this.onSelect,
  });

  final List<FilterOption> options;

  /// Null means "any location".
  final String? selectedCode;

  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.length < 2) return const SizedBox.shrink();
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'orders.guided_filter.stock_location'.tr,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: context.rsp(11.5),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: context.rh(6)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _LocationChip(
                label: 'orders.guided_filter.stock_location_any'.tr,
                selected: selectedCode == null,
                onTap: () => onSelect(null),
              ),
              for (final option in options) ...[
                SizedBox(width: context.rw(8)),
                _LocationChip(
                  label: option.label,
                  // The count is the whole reason a rep picks one branch over
                  // another, so it is on the chip rather than a tap away.
                  countLabel: 'orders.guided_filter.sku_count'
                      .trParams({'count': option.matchCount}),
                  selected: selectedCode == option.value,
                  onTap: () => onSelect(
                      selectedCode == option.value ? null : option.value),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.countLabel,
  });

  final String label;
  final String? countLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? scheme.primary : colors.surfaceSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warehouse_rounded,
                size: context.rr(13),
                color: selected ? scheme.onPrimary : colors.iconMuted,
              ),
              SizedBox(width: context.rw(5)),
              Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.onPrimary : colors.textPrimary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (countLabel != null) ...[
                SizedBox(width: context.rw(5)),
                Text(
                  countLabel!,
                  style: TextStyle(
                    color: selected
                        ? scheme.onPrimary.withValues(alpha: 0.85)
                        : colors.textSecondary,
                    fontSize: context.rsp(10.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
