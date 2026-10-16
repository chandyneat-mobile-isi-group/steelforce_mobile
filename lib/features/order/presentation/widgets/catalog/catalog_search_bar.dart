import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class CatalogSearchBar extends StatelessWidget {
  const CatalogSearchBar({
    super.key,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.hasActiveFilters,
    required this.onVoiceTap,
    required this.onImageTap,
    this.controller,
  });

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final bool hasActiveFilters;
  final VoidCallback onVoiceTap;
  final VoidCallback onImageTap;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appColors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: context.rh(44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: appColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.5), size: 20),
                SizedBox(width: context.rw(8)),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSearchChanged,
                    style: TextStyle(
                        color: scheme.onSurface, fontSize: context.rsp(13.5)),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'orders.catalog.search_hint'.tr,
                      hintStyle: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.4),
                          fontSize: context.rsp(13.5)),
                    ),
                  ),
                ),
                _InlineIcon(
                    icon: Icons.mic_none_rounded,
                    tooltip: 'orders.voice.tooltip'.tr,
                    onTap: onVoiceTap),
                _InlineIcon(
                    icon: Icons.photo_camera_back_outlined,
                    tooltip: 'orders.catalog.search_by_photo'.tr,
                    onTap: onImageTap),
              ],
            ),
          ),
        ),
        SizedBox(width: context.rw(10)),
        _SquareButton(
            icon: Icons.tune_rounded,
            highlighted: hasActiveFilters,
            onTap: onFilterTap),
      ],
    );
  }
}

class _InlineIcon extends StatelessWidget {
  const _InlineIcon(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.all(context.rr(4)),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              size: context.rr(20)),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton(
      {required this.icon, required this.onTap, this.highlighted = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: context.rh(44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: highlighted ? scheme.primary : context.appColors.border),
        ),
        child: Icon(icon,
            color: highlighted ? scheme.primary : scheme.onSurface,
            size: context.rr(20)),
      ),
    );
  }
}
