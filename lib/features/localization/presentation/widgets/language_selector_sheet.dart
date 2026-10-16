import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/localization/domain/entities/language_entity.dart';
import 'package:steelforce/features/localization/presentation/bloc/language_cubit.dart';
import 'package:steelforce/features/localization/presentation/widgets/language_reload_dialog.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Opens the language picker. Tapping a language applies it **instantly**
/// (every `.tr` in the live tree re-resolves — no restart), persists it, and
/// closes the sheet after a short beat so the user sees the switch land in
/// their new language. The [LanguageCubit] is read from an ancestor provider,
/// so this works from anywhere below `MaterialApp`.
Future<void> showLanguageSelectorSheet(BuildContext context) {
  final languageCubit = context.read<LanguageCubit>();
  final isTablet = MediaQuery.sizeOf(context).width >= 600;

  if (isTablet) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LanguageSelector',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 520,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: BlocProvider.value(
                value: languageCubit,
                child: const _LanguageSelectorSheet(isTablet: true),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: child,
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: languageCubit,
      child: const _LanguageSelectorSheet(isTablet: false),
    ),
  );
}

class _LanguageSelectorSheet extends StatefulWidget {
  const _LanguageSelectorSheet({this.isTablet = false});

  final bool isTablet;

  @override
  State<_LanguageSelectorSheet> createState() => _LanguageSelectorSheetState();
}

class _LanguageSelectorSheetState extends State<_LanguageSelectorSheet> {
  /// Code currently being applied, for the per-tile progress spinner.
  String? _switching;

  Future<void> _select(String code) async {
    if (_switching != null) return;
    final cubit = context.read<LanguageCubit>();
    if (cubit.state.languageCode == code) {
      Navigator.of(context).pop();
      return;
    }

    final target = cubit.supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => cubit.supportedLanguages.first,
    );
    final confirmed = await showLanguageReloadConfirmDialog(context, target);
    if (!confirmed || !mounted) return;

    setState(() => _switching = code);
    await cubit.changeLanguage(code);

    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(Static.main, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LocalizedBuilder(
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.isTablet ? 28 : 20,
            widget.isTablet ? 24 : 4,
            widget.isTablet ? 28 : 20,
            widget.isTablet ? 28 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'language.choose_title'.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: widget.isTablet ? 20 : null,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (widget.isTablet)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'language.choose_subtitle'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: widget.isTablet ? 14 : null,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: widget.isTablet ? 20 : 16),
              BlocBuilder<LanguageCubit, Locale>(
                builder: (context, locale) => Column(
                  children: [
                    for (final language
                        in context.read<LanguageCubit>().supportedLanguages)
                      LanguageOptionTile(
                        language: language,
                        selected: locale.languageCode == language.code,
                        switching: _switching == language.code,
                        isTablet: widget.isTablet,
                        onTap: () => _select(language.code),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One selectable language row: flag, native name, region line, animated
/// radio that morphs into a progress spinner while that language loads.
class LanguageOptionTile extends StatelessWidget {
  const LanguageOptionTile({
    super.key,
    required this.language,
    required this.selected,
    required this.onTap,
    this.switching = false,
    this.isTablet = false,
  });

  final LanguageEntity language;
  final bool selected;
  final bool switching;
  final bool isTablet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Material(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 18 : 14,
                vertical: isTablet ? 16 : 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: isTablet ? 48 : 40,
                    height: isTablet ? 48 : 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.16)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      language.flag,
                      style: TextStyle(fontSize: isTablet ? 24 : 20),
                    ),
                  ),
                  SizedBox(width: isTablet ? 18 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.nameKey.tr,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isTablet ? 17 : null,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          language.regionKey.tr,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: isTablet ? 13.5 : null,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  switching
                      ? SizedBox(
                          width: isTablet ? 26 : 22,
                          height: isTablet ? 26 : 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected ? scheme.primary : scheme.outline,
                          size: isTablet ? 26 : 22,
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
