import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The always-visible entry point into the catalog.
///
/// It stays on screen at every stage of the configurator — before a category
/// is chosen, mid-hierarchy, and over the results — because the two ways reps
/// actually work are different: a new rep browses the hierarchy, an
/// experienced one types the material code they already know. Hiding this
/// until the filters were complete made the second rep do the first rep's
/// work.
///
/// Searches name, code, SKU, barcode, material code and description; voice and
/// photo lookup resolve to text and feed the same field.
class ProductSearchBar extends StatelessWidget {
  const ProductSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
    this.activeFilterCount = 0,
    this.onVoiceTap,
    this.onImageTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Opens the filter sheet — sort, stock, reset. Always available, so
  /// "undo what I just did" is never more than one tap away.
  final VoidCallback onFilterTap;

  /// Drives the badge on the filter button.
  final int activeFilterCount;

  final VoidCallback? onVoiceTap;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: context.rh(46),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    color: colors.iconMuted, size: context.rr(20)),
                SizedBox(width: context.rw(8)),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                        color: colors.textPrimary, fontSize: context.rsp(13.5)),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'orders.guided_filter.search_hint'.tr,
                      hintStyle: TextStyle(
                          color: colors.textHint, fontSize: context.rsp(13)),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: value.text.isEmpty
                        ? const SizedBox.shrink()
                        : InkWell(
                            key: const ValueKey('clear'),
                            onTap: () {
                              controller.clear();
                              onChanged('');
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Icon(Icons.close_rounded,
                                color: colors.iconMuted, size: context.rr(18)),
                          ),
                  ),
                ),
                if (onVoiceTap != null)
                  _IconAction(icon: Icons.mic_none_rounded, onTap: onVoiceTap!),
                if (onImageTap != null)
                  _IconAction(
                      icon: Icons.photo_camera_outlined, onTap: onImageTap!),
              ],
            ),
          ),
        ),
        SizedBox(width: context.rw(8)),
        _FilterButton(count: activeFilterCount, onTap: onFilterTap),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(icon,
              color: context.appColors.iconMuted, size: context.rr(19)),
        ),
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final active = count > 0;

    return Tooltip(
      message: 'orders.guided_filter.filters'.tr,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: context.rh(46),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: 0.12)
              : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? scheme.primary : colors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: context.rr(19),
                      color: active ? scheme.primary : colors.iconMuted),
                  if (active) ...[
                    SizedBox(width: context.rw(6)),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: context.rsp(12.5),
                        fontWeight: FontWeight.w800,
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
