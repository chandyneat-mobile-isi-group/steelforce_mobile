import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/loading_products.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Renders *any* specification step the backend defines — Thickness, Colour,
/// Shape, Grade, Diameter, or something merchandising invents next quarter.
///
/// There is no switch on step key anywhere in this widget. It reads
/// [FilterStep.style] (published by SAP) to decide between chips and a value
/// grid, and [FilterStep.label] for the heading. Adding a filter level to a
/// category is therefore a backend change, not a release.
class DynamicFilterSection extends StatelessWidget {
  const DynamicFilterSection({
    super.key,
    required this.step,
    required this.options,
    required this.onSelect,
    this.selectedValue,
    this.loading = false,
  });

  final FilterStep step;
  final List<FilterOption> options;
  final ValueChanged<FilterOption> onSelect;
  final String? selectedValue;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return step.style == FilterStepStyle.grid
          ? LoadingProducts.grid()
          : LoadingProducts.chips();
    }

    return switch (step.style) {
      FilterStepStyle.grid => _OptionGrid(
          options: options,
          selectedValue: selectedValue,
          onSelect: onSelect,
        ),
      FilterStepStyle.chips || FilterStepStyle.list => _OptionChips(
          options: options,
          selectedValue: selectedValue,
          onSelect: onSelect,
        ),
    };
  }
}

class _OptionChips extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selectedValue,
    required this.onSelect,
  });

  final List<FilterOption> options;
  final String? selectedValue;
  final ValueChanged<FilterOption> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < options.length; i++)
            FilterFlowStaggeredItem(
              index: i,
              child: _OptionSurface(
                option: options[i],
                selected: options[i].value == selectedValue,
                onTap: () => onSelect(options[i]),
                shape: _OptionShape.pill,
              ),
            ),
        ],
      );
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.options,
    required this.selectedValue,
    required this.onSelect,
  });

  final List<FilterOption> options;
  final String? selectedValue;
  final ValueChanged<FilterOption> onSelect;

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
            childAspectRatio: 1.9,
          ),
          itemBuilder: (context, index) => FilterFlowStaggeredItem(
            index: index,
            child: _OptionSurface(
              option: options[index],
              selected: options[index].value == selectedValue,
              onTap: () => onSelect(options[index]),
              shape: _OptionShape.tile,
            ),
          ),
        );
      },
    );
  }
}

enum _OptionShape { pill, tile }

class _OptionSurface extends StatelessWidget {
  const _OptionSurface({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.shape,
  });

  final FilterOption option;
  final bool selected;
  final VoidCallback onTap;
  final _OptionShape shape;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final radius = shape == _OptionShape.pill ? 20.0 : 12.0;

    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: FilterFlowTransition.duration,
      curve: FilterFlowTransition.curve,
      child: AnimatedContainer(
        duration: FilterFlowTransition.duration,
        curve: FilterFlowTransition.curve,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? scheme.primary : colors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: shape == _OptionShape.pill ? 16 : 10,
                vertical: shape == _OptionShape.pill ? 10 : 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? scheme.primary : colors.textPrimary,
                      fontSize: context.rsp(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (shape == _OptionShape.tile) ...[
                    SizedBox(height: context.rh(2)),
                    Text(
                      '${option.matchCount}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(10.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
