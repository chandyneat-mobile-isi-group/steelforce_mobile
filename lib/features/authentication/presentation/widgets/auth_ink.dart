import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';

/// The sign-in and password-reset screens' ink, on their white chevron
/// backdrop. One set for every screen in the flow, so they read as one
/// surface. Contrast on white, against WCAG AA's 4.5:1 for text:
/// [text] 16.2:1 · [muted] 6.3:1 · [accent] 8.6:1 · [error] 4.8:1.
abstract final class AuthInk {
  /// Headlines, field values, icons: Ironclad navy.
  static const text = AppColors.brandNavy;

  /// Secondary copy, labels, placeholders: the lockup's blue-grey.
  static const muted = Color(0xFF4D6480);

  /// Hairlines and dividers: navy at 15%.
  static const hairline = Color(0x26011E41);

  /// Links, focus, the accent word: Apex Blue.
  static const accent = AppColors.primary;

  /// Validation and failures.
  static const error = Color(0xFFDC2626);

  /// Inside a field or a code box.
  static const fieldFill = Color(0xFFF4F7FB);

  /// A field's resting outline.
  static const fieldBorder = Color(0xFFC5D1E0);

  /// The white backdrop's chevron lines: navy at 5%.
  static const patternLine = Color(0x0D011E41);
}

/// Holds the auth screens in the light theme whatever the phone's setting:
/// the backdrop is white, so dark mode's white text would vanish on it.
class AuthLightTheme extends StatelessWidget {
  const AuthLightTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final font = Theme.of(context).textTheme.bodyMedium?.fontFamily ??
        AppTypography.latinFontFamily;
    return Theme(data: AppTheme.light(font), child: child);
  }
}
