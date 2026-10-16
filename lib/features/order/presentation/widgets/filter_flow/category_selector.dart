import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/category_icons/category_icon.dart';

/// Responsive grid selector featuring a 3D tactile card design with dual ambient shadows,
/// bevel gradients, and a premium "Read More" expander button.
class CategorySelector extends StatefulWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.onSelect,
    this.selectedCategoryId,
  });

  final List<MaterialCategory> categories;
  final ValueChanged<MaterialCategory> onSelect;

  /// The selected category's [MaterialCategory.code].
  final String? selectedCategoryId;

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    // Detect if the device is a tablet/iPad (shortest side >= 600dp is standard)
    final bool isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    // Set columns and rows dynamically
    final int crossAxisCount = isTablet ? 6 : 4;
    // Tablet: 6 cols * 4 rows = 24. Mobile: 4 cols * 2 rows = 8.
    final int maxInitialItems = isTablet ? 24 : 8;

    final hasMore = widget.categories.length > maxInitialItems;
    final visibleCategories = (_isExpanded || !hasMore)
        ? widget.categories
        : widget.categories.take(maxInitialItems).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(2), vertical: context.rh(4)),
          itemCount: visibleCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: context.rh(10),
            crossAxisSpacing: context.rw(10),
            childAspectRatio: 0.80,
          ),
          itemBuilder: (context, index) {
            final category = visibleCategories[index];
            return FilterFlowStaggeredItem(
              index: index,
              child: _CategoryTile(
                category: category,
                selected: category.code == widget.selectedCategoryId,
                onTap: () => widget.onSelect(category),
              ),
            );
          },
        ),
        if (hasMore) ...[
          SizedBox(height: context.rh(8)),
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(context.rr(20)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                      horizontal: context.rw(16), vertical: context.rh(6)),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(context.rr(20)),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.25),
                      width: context.rw(1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.08),
                        blurRadius: 8.r,
                        offset: Offset(0, context.rh(3)),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        blurRadius: 1.r,
                        offset: Offset(0, -context.rh(1)),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Show Less' : 'Read More',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: context.rsp(11.5),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      SizedBox(width: context.rw(4)),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: context.rsp(16),
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final MaterialCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: FilterFlowTransition.duration,
      curve: FilterFlowTransition.curve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(14)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.primary.withValues(alpha: 0.04),
                ]
              : [
                  colors.card,
                  colors.surfaceSoft,
                ],
        ),
        border: Border.all(
          color:
              selected ? scheme.primary : colors.border.withValues(alpha: 0.8),
          width: selected ? context.rw(1.5) : context.rw(1),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.22),
                  blurRadius: 10.r,
                  offset: Offset(0, context.rh(4)),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 2.r,
                  offset: Offset(0, -context.rh(1)),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6.r,
                  offset: Offset(0, context.rh(3)),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 1.r,
                  offset: Offset(0, -context.rh(1)),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rr(14)),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.rw(4), vertical: context.rh(8)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 3D Embossed Icon Badge
                Container(
                  padding: EdgeInsets.all(context.rr(7)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: selected
                          ? [
                              scheme.primary.withValues(alpha: 0.22),
                              scheme.primary.withValues(alpha: 0.08),
                            ]
                          : [
                              colors.card,
                              colors.border.withValues(alpha: 0.25),
                            ],
                    ),
                    border: Border.all(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.4)
                          : colors.border.withValues(alpha: 0.5),
                      width: context.rw(1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4.r,
                        offset: Offset(0, context.rh(2)),
                      ),
                    ],
                  ),
                  child: CategoryIcon(
                    code: category.icon ?? category.code,
                    name: context.localized(category.name),
                    active: selected,
                    showChip: false,
                    size: context.rsp(24),
                  ),
                ),
                SizedBox(height: context.rh(6)),
                // Category Text Label
                Text(
                  context.localized(category.name),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? scheme.primary : colors.textPrimary,
                    fontSize: context.rsp(10.5),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: 1.15,
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
