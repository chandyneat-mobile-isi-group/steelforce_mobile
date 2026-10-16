import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// What the always-visible Filter button opens.
///
/// Everything here is a preference *over* the result set — sort order, stock
/// availability, and clearing what's already chosen. The hierarchy itself is
/// not editable from here on purpose: those answers have dependencies between
/// them, and editing them out of order is what the chip bar handles correctly.
///
/// Deliberately extensible: new preferences slot in as further sections
/// without any caller changing.
class FilterOptionsSheet extends StatefulWidget {
  const FilterOptionsSheet({
    super.key,
    required this.sortBy,
    required this.availableOnly,
    required this.selection,
    required this.categoryLabel,
  });

  final ProductSortBy sortBy;
  final bool availableOnly;
  final FilterSelection selection;
  final String? categoryLabel;

  @override
  State<FilterOptionsSheet> createState() => _FilterOptionsSheetState();
}

/// What the sheet was closed with. `clearedStepKeys` and `clearAll` are
/// reported rather than applied here — the invalidation rules live in the
/// bloc, and a sheet is the wrong place to duplicate them.
class FilterOptionsResult {
  const FilterOptionsResult({
    required this.sortBy,
    required this.availableOnly,
    this.clearedStepKeys = const [],
    this.clearAll = false,
  });

  final ProductSortBy sortBy;
  final bool availableOnly;
  final List<String> clearedStepKeys;
  final bool clearAll;
}

class _FilterOptionsSheetState extends State<FilterOptionsSheet> {
  late ProductSortBy _sortBy = widget.sortBy;
  late bool _availableOnly = widget.availableOnly;
  final Set<String> _cleared = {};

  void _apply({bool clearAll = false}) {
    Navigator.of(context).pop(FilterOptionsResult(
      sortBy: _sortBy,
      availableOnly: _availableOnly,
      clearedStepKeys: _cleared.toList(),
      clearAll: clearAll,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final steps = widget.selection.entries;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: context.rh(16)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'orders.guided_filter.filters'.tr,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(17),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _apply(clearAll: true),
                  child: Text('common.clear_all'.tr,
                      style: TextStyle(color: colors.warning)),
                ),
              ],
            ),
            SizedBox(height: context.rh(8)),
            _SectionLabel('orders.guided_filter.sort_by'.tr),
            SizedBox(height: context.rh(8)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sort in ProductSortBy.values)
                  _ChoiceChip(
                    label: _sortLabel(sort),
                    selected: _sortBy == sort,
                    onTap: () => setState(() => _sortBy = sort),
                  ),
              ],
            ),
            SizedBox(height: context.rh(20)),
            _SectionLabel('orders.guided_filter.availability'.tr),
            SizedBox(height: context.rh(4)),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _availableOnly,
              onChanged: (value) => setState(() => _availableOnly = value),
              title: Text(
                'orders.filter.in_stock_only'.tr,
                style: TextStyle(
                    color: colors.textPrimary, fontSize: context.rsp(14)),
              ),
            ),
            if (widget.categoryLabel != null) ...[
              SizedBox(height: context.rh(8)),
              _SectionLabel('orders.guided_filter.active_filters'.tr),
              SizedBox(height: context.rh(8)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StaticChip(label: widget.categoryLabel!),
                  for (final entry in steps)
                    _ChoiceChip(
                      label: '${entry.stepLabel}: ${entry.option.label}',
                      selected: !_cleared.contains(entry.stepKey),
                      trailingIcon: Icons.close_rounded,
                      onTap: () => setState(() =>
                          _cleared.contains(entry.stepKey)
                              ? _cleared.remove(entry.stepKey)
                              : _cleared.add(entry.stepKey)),
                    ),
                ],
              ),
              if (_cleared.isNotEmpty) ...[
                SizedBox(height: context.rh(8)),
                Text(
                  'orders.guided_filter.clear_dependents_note'.tr,
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: context.rsp(11.5)),
                ),
              ],
            ],
            SizedBox(height: context.rh(20)),
            SizedBox(
              height: context.rh(46),
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('orders.guided_filter.apply'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sortLabel(ProductSortBy sort) => switch (sort) {
        ProductSortBy.relevance => 'orders.filter.sort_relevance'.tr,
        ProductSortBy.nameAsc => 'orders.filter.sort_name_az'.tr,
        ProductSortBy.priceAsc => 'orders.filter.sort_price_low_high'.tr,
        ProductSortBy.priceDesc => 'orders.filter.sort_price_high_low'.tr,
        ProductSortBy.stockDesc => 'orders.filter.sort_stock_high_low'.tr,
      };
}

/// Opens the filter sheet and returns what the rep chose, or null if they
/// dismissed it without applying.
Future<FilterOptionsResult?> showFilterOptionsSheet({
  required BuildContext context,
  required ProductSortBy sortBy,
  required bool availableOnly,
  required FilterSelection selection,
  required String? categoryLabel,
}) {
  return showModalBottomSheet<FilterOptionsResult>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FilterOptionsSheet(
      sortBy: sortBy,
      availableOnly: availableOnly,
      selection: selection,
      categoryLabel: categoryLabel,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.appColors.textSecondary,
          fontSize: context.rsp(11),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      );
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? scheme.primary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? scheme.primary : colors.textSecondary,
                fontSize: context.rsp(12.5),
                fontWeight: FontWeight.w700,
                decoration: selected ? null : TextDecoration.lineThrough,
              ),
            ),
            if (trailingIcon != null) ...[
              SizedBox(width: context.rw(5)),
              Icon(trailingIcon,
                  size: context.rr(13),
                  color: selected ? scheme.primary : colors.iconMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaticChip extends StatelessWidget {
  const _StaticChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: context.rsp(12.5),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
