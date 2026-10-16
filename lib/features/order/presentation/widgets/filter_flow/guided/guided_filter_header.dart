import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_chip_bar.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_search_bar.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Search, filter and the active-filter trail. Never hidden, at any stage.
class GuidedFilterHeader extends StatelessWidget {
  const GuidedFilterHeader({
    super.key,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onVoiceTap,
    required this.onImageTap,
    required this.onClearStep,
    required this.onClearCategory,
    required this.onBack,
  });

  final ProductFilterFlowState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onImageTap;
  final ValueChanged<String> onClearStep;
  final VoidCallback onClearCategory;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductSearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
          onFilterTap: onFilterTap,
          activeFilterCount: _activeFilterCount,
          onVoiceTap: onVoiceTap,
          onImageTap: onImageTap,
        ),
        // AnimatedSize rather than a conditional child, so the header grows
        // into the chip row instead of the content below it jumping.
        AnimatedSize(
          duration: FilterFlowTransition.duration,
          curve: FilterFlowTransition.curve,
          alignment: Alignment.topCenter,
          child: state.category == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: FilterChipBar(
                    categoryLabel: context.localized(state.category!.name),
                    selection: state.selection,
                    onClearStep: onClearStep,
                    onClearCategory: onClearCategory,
                    trailing: _BackButton(onPressed: onBack),
                  ),
                ),
        ),
      ],
    );
  }

  /// Category + answered steps + stock + non-default sort. Search is excluded:
  /// it has its own visible field, so counting it would double-report.
  int get _activeFilterCount {
    var count = state.selection.entries.length;
    if (state.category != null) count++;
    if (state.availableOnly) count++;
    if (state.sortBy.name != 'relevance') count++;
    return count;
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: 'common.back'.tr,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Icon(Icons.undo_rounded,
              size: context.rr(16), color: colors.textPrimary),
        ),
      ),
    );
  }
}
