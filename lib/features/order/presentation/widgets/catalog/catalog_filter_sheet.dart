import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

Future<void> showCatalogFilterSheet({
  required BuildContext context,
  required ProductFilter filter,
  required List<String> brands,
  required void Function(ProductFilter filter) onApply,
}) {
  final appColors = context.appColors;

  return showModalBottomSheet<void>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    backgroundColor: appColors.surfaceSoft,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) =>
        _CatalogFilterSheet(filter: filter, brands: brands, onApply: onApply),
  );
}

class _CatalogFilterSheet extends StatefulWidget {
  const _CatalogFilterSheet(
      {required this.filter, required this.brands, required this.onApply});
  final ProductFilter filter;
  final List<String> brands;
  final void Function(ProductFilter filter) onApply;

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late String? _brand = widget.filter.brand;
  late bool _availableOnly = widget.filter.availableOnly;
  late ProductSortBy _sortBy = widget.filter.sortBy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('common.filter_sort'.tr,
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: context.rsp(17),
                            fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _brand = null;
                      _availableOnly = false;
                      _sortBy = ProductSortBy.relevance;
                    }),
                    child: Text('common.clear'.tr,
                        style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.5))),
                  ),
                ],
              ),
              SizedBox(height: context.rh(12)),
              _Label('common.sort_by'.tr),
              _ChipGroup<ProductSortBy>(
                options: {
                  ProductSortBy.relevance: 'orders.filter.sort_relevance'.tr,
                  ProductSortBy.nameAsc: 'orders.filter.sort_name_az'.tr,
                  ProductSortBy.priceAsc:
                      'orders.filter.sort_price_low_high'.tr,
                  ProductSortBy.priceDesc:
                      'orders.filter.sort_price_high_low'.tr,
                  ProductSortBy.stockDesc:
                      'orders.filter.sort_stock_high_low'.tr,
                },
                selected: _sortBy,
                onSelected: (v) => setState(() => _sortBy = v),
              ),
              SizedBox(height: context.rh(16)),
              _Label('orders.filter.brand'.tr),
              _ChipGroup<String?>(
                options: {
                  null: 'common.any'.tr,
                  for (final b in widget.brands) b: b
                },
                selected: _brand,
                onSelected: (v) => setState(() => _brand = v),
              ),
              SizedBox(height: context.rh(16)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _availableOnly,
                onChanged: (v) => setState(() => _availableOnly = v),
                activeThumbColor: scheme.primary,
                title: Text('orders.filter.in_stock_only'.tr,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: context.rsp(13),
                        fontWeight: FontWeight.w600)),
              ),
              SizedBox(height: context.rh(8)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(widget.filter.copyWith(
                      brand: () => _brand,
                      availableOnly: _availableOnly,
                      sortBy: _sortBy,
                    ));
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('common.apply'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w700)),
      );
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup(
      {required this.options,
      required this.selected,
      required this.onSelected});
  final Map<T, String> options;
  final T selected;
  final void Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appColors = context.appColors;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final isSelected = e.key == selected;
        return InkWell(
          onTap: () => onSelected(e.key),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.15)
                  : scheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: isSelected ? scheme.primary : appColors.border),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: isSelected ? scheme.primary : scheme.onSurface,
                fontSize: context.rsp(12.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
