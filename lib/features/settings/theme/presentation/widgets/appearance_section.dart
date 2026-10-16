import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_cubit.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_state.dart';
import 'package:steelforce/features/settings/theme/presentation/widgets/theme_option_meta.dart';
import 'package:steelforce/features/settings/theme/presentation/widgets/theme_selector_sheet.dart';
import 'package:steelforce/shared/widgets/settings_section_card.dart';

/// "Appearance" block for the Profile screen — a single **Theme** row that opens
/// the [showThemeSelectorSheet] picker and reflects the active selection live
/// via [ThemeCubit].
///
/// Layout, padding, and type come from [SettingsSectionCard] / [SettingsRow],
/// which this shares with `LanguageSection` — see that widget's doc for why the
/// two are no longer allowed to define their own metrics.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'appearance.title'.tr,
      children: [
        BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, state) {
            final mode = state.mode;
            return SettingsRow(
              icon: mode.icon,
              label: 'appearance.theme'.tr,
              value: mode.labelKey.tr,
              onTap: () => showThemeSelectorSheet(context),
            );
          },
        ),
      ],
    );
  }
}
