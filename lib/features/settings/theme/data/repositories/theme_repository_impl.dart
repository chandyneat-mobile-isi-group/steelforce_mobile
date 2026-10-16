import 'package:steelforce/core/database/hive/app_preferences.dart';
import 'package:steelforce/features/settings/theme/domain/entities/app_theme_mode.dart';
import 'package:steelforce/features/settings/theme/domain/repositories/theme_repository.dart';

/// [ThemeRepository] backed by the Hive-based [AppPreferences] cache box — the
/// same non-sensitive store used for language and onboarding, so no new box or
/// migration is needed.
class ThemeRepositoryImpl implements ThemeRepository {
  const ThemeRepositoryImpl(this._prefs);

  final AppPreferences _prefs;

  /// Bumped when the persisted shape of theme prefs changes.
  static const int _currentVersion = 1;

  @override
  AppThemeMode getThemeMode() =>
      AppThemeMode.fromStorage(_prefs.savedThemeMode);

  @override
  AppThemeMode? getLastThemeMode() {
    final stored = _prefs.lastThemeMode;
    return stored == null ? null : AppThemeMode.fromStorage(stored);
  }

  @override
  int getThemeVersion() => _prefs.themeVersion;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    // Roll the current active mode into "last selected" before overwriting.
    final current = _prefs.savedThemeMode;
    if (current != null && current != mode.storageValue) {
      await _prefs.setLastThemeMode(current);
    }
    await _prefs.setThemeMode(mode.storageValue);
    await _prefs.setThemeVersion(_currentVersion);
  }
}
