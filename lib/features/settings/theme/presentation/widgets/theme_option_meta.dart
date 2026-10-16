import 'package:flutter/material.dart';
import 'package:steelforce/features/settings/theme/domain/entities/app_theme_mode.dart';

/// UI metadata for an [AppThemeMode] — the icon and the localization key for
/// its label. Kept in one place so the Appearance row and the selector sheet
/// can't drift apart.
extension AppThemeModePresentation on AppThemeMode {
  IconData get icon => switch (this) {
        AppThemeMode.light => Icons.light_mode_rounded,
        AppThemeMode.dark => Icons.dark_mode_rounded,
        AppThemeMode.system => Icons.brightness_auto_rounded,
      };

  /// Localization key for the mode's display name.
  String get labelKey => switch (this) {
        AppThemeMode.light => 'appearance.light',
        AppThemeMode.dark => 'appearance.dark',
        AppThemeMode.system => 'appearance.system',
      };

  /// Localization key for a short one-line description.
  String get descriptionKey => switch (this) {
        AppThemeMode.light => 'appearance.light_hint',
        AppThemeMode.dark => 'appearance.dark_hint',
        AppThemeMode.system => 'appearance.system_hint',
      };
}
