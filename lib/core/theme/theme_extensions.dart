import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors_dark.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// Semantic, theme-aware design tokens that don't map cleanly onto a Material 3
/// [ColorScheme] role — the app's own vocabulary (card, canvas, success,
/// warning, brand navy, …) resolved for the active brightness.
///
/// This is the bridge that lets the app's custom-painted surfaces flip with the
/// theme. Read it from a widget with:
///
/// ```dart
/// final c = Theme.of(context).extension<AppThemeColors>()!;
/// color: c.card,
/// ```
///
/// In **Phase 1** it is attached to both [ThemeData]s and used by the new theme
/// UI. In **Phase 2** the existing `Vibe.*` / hardcoded-color call sites migrate
/// onto these tokens (or `colorScheme` where a Material role fits), so every
/// screen tracks light/dark without touching business logic.
///
/// Anything that already has a first-class Material role — `primary`, `surface`,
/// `error`, `onSurface`, `outline`, … — deliberately lives on [ColorScheme], not
/// here, to avoid two sources of truth.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.card,
    required this.canvas,
    required this.surfaceSoft,
    required this.surfaceStrong,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textDisabled,
    required this.iconMuted,
    required this.primaryHover,
    required this.success,
    required this.warning,
    required this.warningAlt,
    required this.info,
    required this.slate,
    required this.brandNavy,
    required this.brandNavyDark,
    required this.accentPurple,
    required this.shadowColor,
  });

  final Color card;
  final Color canvas;
  final Color surfaceSoft;
  final Color surfaceStrong;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color textDisabled;
  final Color iconMuted;
  final Color primaryHover;
  final Color success;
  final Color warning;
  final Color warningAlt;
  final Color info;

  /// Solid dark chip/banner background (e.g. connectivity + sync overlays).
  final Color slate;
  final Color brandNavy;
  final Color brandNavyDark;
  final Color accentPurple;
  final Color shadowColor;

  /// Soft elevation for flat enterprise cards — resolved for the active theme
  /// (replaces the const `Vibe.cardShadow`).
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Light-mode tokens — sourced from the existing [AppColors] so light mode is
  /// pixel-identical to today.
  static const AppThemeColors light = AppThemeColors(
    card: AppColors.card,
    canvas: AppColors.canvas,
    surfaceSoft: AppColors.backgroundSoft,
    surfaceStrong: AppColors.surfaceStrong,
    border: AppColors.border,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textHint: AppColors.textHint,
    textDisabled: AppColors.textDisabled,
    iconMuted: AppColors.iconMuted,
    primaryHover: AppColors.primaryHover,
    success: AppColors.success,
    warning: AppColors.warning,
    warningAlt: AppColors.warningAlt,
    info: AppColors.info,
    slate: AppColors.slate,
    brandNavy: AppColors.brandNavy,
    brandNavyDark: AppColors.brandNavyDark,
    accentPurple: AppColors.accentPurple,
    shadowColor: AppColors.shadow,
  );

  /// Dark-mode tokens — sourced from [AppColorsDark].
  static const AppThemeColors dark = AppThemeColors(
    card: AppColorsDark.card,
    canvas: AppColorsDark.canvas,
    surfaceSoft: AppColorsDark.backgroundSoft,
    surfaceStrong: AppColorsDark.surfaceStrong,
    border: AppColorsDark.border,
    divider: AppColorsDark.divider,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    textHint: AppColorsDark.textHint,
    textDisabled: AppColorsDark.textDisabled,
    iconMuted: AppColorsDark.iconMuted,
    primaryHover: AppColorsDark.primaryHover,
    success: AppColorsDark.success,
    warning: AppColorsDark.warning,
    warningAlt: AppColorsDark.warningAlt,
    info: AppColorsDark.info,
    slate: AppColorsDark.surfaceContainer,
    brandNavy: AppColorsDark.brandNavy,
    brandNavyDark: AppColorsDark.brandNavyDark,
    accentPurple: AppColorsDark.accentPurple,
    shadowColor: AppColorsDark.shadow,
  );

  @override
  AppThemeColors copyWith({
    Color? card,
    Color? canvas,
    Color? surfaceSoft,
    Color? surfaceStrong,
    Color? border,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? textDisabled,
    Color? iconMuted,
    Color? primaryHover,
    Color? success,
    Color? warning,
    Color? warningAlt,
    Color? info,
    Color? slate,
    Color? brandNavy,
    Color? brandNavyDark,
    Color? accentPurple,
    Color? shadowColor,
  }) {
    return AppThemeColors(
      card: card ?? this.card,
      canvas: canvas ?? this.canvas,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      textDisabled: textDisabled ?? this.textDisabled,
      iconMuted: iconMuted ?? this.iconMuted,
      primaryHover: primaryHover ?? this.primaryHover,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      warningAlt: warningAlt ?? this.warningAlt,
      info: info ?? this.info,
      slate: slate ?? this.slate,
      brandNavy: brandNavy ?? this.brandNavy,
      brandNavyDark: brandNavyDark ?? this.brandNavyDark,
      accentPurple: accentPurple ?? this.accentPurple,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      card: Color.lerp(card, other.card, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningAlt: Color.lerp(warningAlt, other.warningAlt, t)!,
      info: Color.lerp(info, other.info, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      brandNavy: Color.lerp(brandNavy, other.brandNavy, t)!,
      brandNavyDark: Color.lerp(brandNavyDark, other.brandNavyDark, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

/// Ergonomic access: `context.appColors.card`.
extension AppThemeColorsX on BuildContext {
  AppThemeColors get appColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;
}
