import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/localization/presentation/bloc/language_cubit.dart';
import 'package:steelforce/features/localization/presentation/widgets/language_selector_sheet.dart';
import 'package:steelforce/shared/widgets/settings_section_card.dart';

/// "Language" block for the Profile screen — a single row showing the active
/// language (flag + native name) that opens [showLanguageSelectorSheet].
///
/// Shares [SettingsSectionCard] / [SettingsRow] with `AppearanceSection` rather
/// than mirroring its layout by hand, which is what let the two drift apart.
class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'settings.language_title'.tr,
      children: [
        BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            final supported = context.read<LanguageCubit>().supportedLanguages;
            final language = supported.firstWhere(
              (l) => l.code == locale.languageCode,
              orElse: () => supported.first,
            );
            return SettingsRow(
              icon: Icons.translate_rounded,
              label: 'settings.language'.tr,
              value: language.nameKey.tr,
              valuePrefix: Text(
                language.flag,
                style: TextStyle(fontSize: context.rsp(14)),
              ),
              onTap: () => showLanguageSelectorSheet(context),
            );
          },
        ),
      ],
    );
  }
}
