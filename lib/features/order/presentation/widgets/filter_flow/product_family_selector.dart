import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The family step (Palm 50 / Palm 70 / Palm 100), rendered as rows rather than
/// chips.
///
/// Families are the level a rep thinks in and the level with the longest names,
/// so they get a full-width row with its SKU count and an affordance that reads
/// as "drill in" — visually distinct from the specification steps that follow,
/// which are terse values.
class ProductFamilySelector extends StatelessWidget {
  const ProductFamilySelector({
    super.key,
    required this.options,
    required this.onSelect,
    this.selectedValue,
    this.countLabelBuilder,
  });

  final List<FilterOption> options;
  final ValueChanged<FilterOption> onSelect;
  final String? selectedValue;

  /// Localised "{count} items" formatter. Kept injectable so this widget stays
  /// free of a localisation dependency and remains trivially golden-testable.
  final String Function(int count)? countLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) => FilterFlowStaggeredItem(
            index: index,
            child: _FamilyCard(
              option: options[index],
              selected: options[index].value == selectedValue,
              countLabel: countLabelBuilder?.call(options[index].matchCount),
              onTap: () => onSelect(options[index]),
            ),
          ),
        );
      },
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.option,
    required this.selected,
    required this.countLabel,
    required this.onTap,
  });

  final FilterOption option;
  final bool selected;
  final String? countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: FilterFlowTransition.duration,
      curve: FilterFlowTransition.curve,
      child: AnimatedContainer(
        duration: FilterFlowTransition.duration,
        curve: FilterFlowTransition.curve,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : colors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          option.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                selected ? scheme.primary : colors.textPrimary,
                            fontSize: context.rsp(13),
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: context.rsp(16),
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
