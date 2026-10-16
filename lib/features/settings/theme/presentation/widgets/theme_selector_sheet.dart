import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/settings/theme/domain/entities/app_theme_mode.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_cubit.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_state.dart';
import 'package:steelforce/features/settings/theme/presentation/widgets/theme_option_meta.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Opens the Material 3 theme picker. Selecting an option applies the theme
/// instantly (the whole app restyles with no restart), persists it, and closes
/// the sheet. The [ThemeCubit] is read from an ancestor provider, so this works
/// from anywhere below `MaterialApp`.
Future<void> showThemeSelectorSheet(BuildContext context) {
  final themeCubit = context.read<ThemeCubit>();
  return showModalBottomSheet<void>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: themeCubit,
      child: const _ThemeSelectorSheet(),
    ),
  );
}

class _ThemeSelectorSheet extends StatelessWidget {
  const _ThemeSelectorSheet();

  // All three modes are offered — System fully works (MaterialApp honours it)
  // and reads as premium (Notion/Slack-style). It can be trimmed to two here
  // without any architecture change if the product prefers.
  static const _modes = AppThemeMode.values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'appearance.choose_theme'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: context.rh(16)),
            BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) => Column(
                children: [
                  for (final mode in _modes)
                    _ThemeOptionTile(
                      mode: mode,
                      selected: state.mode == mode,
                      onTap: () async {
                        await context.read<ThemeCubit>().setThemeMode(mode);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: context.rh(40),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.16)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    mode.icon,
                    size: context.rr(22),
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: context.rw(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.labelKey.tr,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      SizedBox(height: context.rh(2)),
                      Text(
                        mode.descriptionKey.tr,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.rw(8)),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? scheme.primary : scheme.outline,
                  size: context.rr(22),
                  semanticLabel: selected ? 'Selected' : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
