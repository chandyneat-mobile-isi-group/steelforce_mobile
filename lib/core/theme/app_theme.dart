import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors_dark.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/animations/page_transitions.dart';

/// Single source of truth for the app's [ThemeData]. Owns the light and dark
/// [ThemeData] objects (previously built inline in `app.dart`), keeps the light
/// theme pixel-identical to the original, and adds a Material 3 dark equivalent.
///
/// Both themes are locale-aware (the font family swaps for Khmer) and **cached**
/// per `(brightness, fontFamily)` so a theme switch or rebuild never re-derives
/// a `ThemeData` that already exists — see [light]/[dark].
class AppTheme {
  AppTheme._();

  static final Map<String, ThemeData> _cache = {};

  /// Light [ThemeData] for [fontFamily]. Cached.
  static ThemeData light(String fontFamily) =>
      _themeFor(Brightness.light, fontFamily);

  /// Dark [ThemeData] for [fontFamily]. Cached.
  static ThemeData dark(String fontFamily) =>
      _themeFor(Brightness.dark, fontFamily);

  static ThemeData _themeFor(Brightness brightness, String fontFamily) {
    final key = '${brightness.name}_$fontFamily';
    return _cache.putIfAbsent(key, () => _build(brightness, fontFamily));
  }

  static ThemeData _build(Brightness brightness, String fontFamily) {
    final isDark = brightness == Brightness.dark;
    // The counterpart script family. Source Sans 3 carries no Khmer glyphs and
    // MiSans Khmer no Latin ones, so every style built here needs the fallback
    // or the other script renders as tofu — see AppTypography's class doc.
    final fontFamilyFallback = AppTypography.fallbackFor(fontFamily);
    final tokens = isDark ? const _DarkTokens() : const _LightTokens();
    final extension = isDark ? AppThemeColors.dark : AppThemeColors.light;

    // Seeded scheme keeps every Material-derived tone (errorContainer,
    // tertiary, outline, ...) that no screen currently overrides; only the
    // slots the app actively renders through are pinned to real design tokens
    // so `Theme.of(context).colorScheme` resolves to them.
    // ── Change this block inside _build(...) ──
    final colorScheme = ColorScheme.fromSeed(
      seedColor:
          tokens.primary, // Use tokens.primary instead of AppColors.primary
      brightness: brightness,
    ).copyWith(
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      secondary: tokens.secondary,
      onSecondary: tokens.onPrimary,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      error: tokens.error,
      onError: tokens.onError,
      outline: tokens.border, // Switch from context.appColors to tokens.border
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Global font family — every screen, dialog, and Material widget inherits
      // it from here unless a widget explicitly overrides fontFamily.
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      textTheme: AppTypography.textTheme(
        tokens.textPrimary,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      ),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.scaffoldBackground,
      // Semantic tokens for the app's custom surfaces (used by the theme UI now,
      // and by migrated screens in Phase 2).
      extensions: [extension],
      // One smooth, modern transition for every MaterialPageRoute push.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const ModernPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.icon),
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.card,
        elevation: 0,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppColors.radius)),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.snackBarBackground,
        contentTextStyle: TextStyle(
          color: tokens.snackBarText,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      // Only touch hint/label/error text colors — no `border`/`filled`
      // defaults, since ~half the app's TextFields build fully custom
      // decorations and a theme-level fill/border would visibly change them.
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: tokens.textHint),
        labelStyle: TextStyle(color: tokens.textSecondary),
        floatingLabelStyle: TextStyle(color: tokens.primary),
        errorStyle: TextStyle(color: tokens.error),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.indicator,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? tokens.selected
                : tokens.unselected,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            color: states.contains(WidgetState.selected)
                ? tokens.selected
                : tokens.unselected,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          disabledBackgroundColor: tokens.unselected,
          disabledForegroundColor: tokens.onPrimary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: tokens.primary),
      ),
    );
  }
}

/// Brightness-resolved primitives consumed by [AppTheme._build]. Kept as a tiny
/// sealed pair so the builder stays a single code path for both brightnesses.
abstract class _Tokens {
  const _Tokens();
  Color get primary;
  Color get onPrimary;
  Color get secondary;
  Color get surface;
  Color get scaffoldBackground;
  Color get card;
  Color get border;
  Color get textPrimary;
  Color get textSecondary;
  Color get textHint;
  Color get icon;
  Color get error;
  Color get onError;
  Color get selected;
  Color get unselected;
  Color get indicator;
  Color get snackBarBackground;
  Color get snackBarText;
}

class _LightTokens extends _Tokens {
  const _LightTokens();
  @override
  Color get primary => AppColors.primary;
  @override
  Color get onPrimary => AppColors.textInverse;
  @override
  Color get secondary => AppColors.secondary;
  @override
  Color get surface => AppColors.surface;
  @override
  Color get scaffoldBackground => AppColors.scaffoldBackground;
  @override
  Color get card => AppColors.card;
  @override
  Color get border => AppColors.border;
  @override
  Color get textPrimary => AppColors.textPrimary;
  @override
  Color get textSecondary => AppColors.textSecondary;
  @override
  Color get textHint => AppColors.textHint;
  @override
  Color get icon => AppColors.icon;
  @override
  Color get error => AppColors.error;
  @override
  Color get onError => AppColors.textInverse;
  @override
  Color get selected => AppColors.selected;
  @override
  Color get unselected => AppColors.unselected;
  @override
  Color get indicator => AppColors.primaryLight;
  @override
  Color get snackBarBackground => AppColors.textInverse;
  @override
  // Must contrast with [snackBarBackground]. This previously also returned
  // `textInverse`, i.e. white text on a white SnackBar: the message was still
  // rendered and still occupied layout, it was simply invisible. A long
  // failure string therefore inflated the (floating, rounded, elevated)
  // SnackBar into a large blank white rectangle floating over the page —
  // reported as a phantom "white widget" on Home and the Route Dashboard.
  // The dark tokens below were always correct, which is why it was light-only.
  Color get snackBarText => AppColors.textPrimary;
}

class _DarkTokens extends _Tokens {
  const _DarkTokens();
  @override
  Color get primary => AppColorsDark.primary;
  @override
  Color get onPrimary => AppColorsDark.textInverse;
  @override
  Color get secondary => AppColorsDark.secondary;
  @override
  Color get surface => AppColorsDark.surface;
  @override
  Color get scaffoldBackground => AppColorsDark.scaffoldBackground;
  @override
  Color get card => AppColorsDark.card;
  @override
  Color get border => AppColorsDark.border;
  @override
  Color get textPrimary => AppColorsDark.textPrimary;
  @override
  Color get textSecondary => AppColorsDark.textSecondary;
  @override
  Color get textHint => AppColorsDark.textHint;
  @override
  Color get icon => AppColorsDark.icon;
  @override
  Color get error => AppColorsDark.error;
  @override
  Color get onError => AppColorsDark.textInverse;
  @override
  Color get selected => AppColorsDark.selected;
  @override
  Color get unselected => AppColorsDark.unselected;
  @override
  Color get indicator => AppColorsDark.surfaceStrong;
  @override
  Color get snackBarBackground => AppColorsDark.surfaceContainer;
  @override
  Color get snackBarText => AppColorsDark.textPrimary;
}
