import 'package:steelforce/features/settings/theme/domain/entities/app_theme_mode.dart';

/// Persistence boundary for the app's theme preference.
///
/// Keeps the [ThemeCubit] free of any storage detail — the cubit only speaks
/// [AppThemeMode]. Reads are synchronous so the saved theme is available before
/// the first frame (no wrong-theme flash on startup); writes are async.
abstract interface class ThemeRepository {
  /// The active theme mode, restored from storage. Returns [AppThemeMode.light]
  /// (the default) when nothing has been saved yet.
  AppThemeMode getThemeMode();

  /// The previously-selected mode, if any — kept for future features such as a
  /// "revert" affordance or usage analytics.
  AppThemeMode? getLastThemeMode();

  /// Schema version of the persisted theme preferences. Lets future releases
  /// migrate the stored shape without guessing.
  int getThemeVersion();

  /// Persists [mode] as the active theme and rolls the current active mode into
  /// "last selected".
  Future<void> saveThemeMode(AppThemeMode mode);
}
