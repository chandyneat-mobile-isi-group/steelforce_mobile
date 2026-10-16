import 'package:steelforce/core/database/hive/app_preferences.dart';

/// Persistence for the language preference, backed by the Hive-based
/// [AppPreferences] cache box (non-sensitive — same store as theme and
/// onboarding, per SECURITY.md §3).
abstract interface class LanguageLocalDatasource {
  /// Saved ISO 639-1 code, or null when the user never chose.
  String? getSavedLanguageCode();

  Future<void> saveLanguageCode(String code);
}

class LanguageLocalDatasourceImpl implements LanguageLocalDatasource {
  LanguageLocalDatasourceImpl(this._prefs);

  final AppPreferences _prefs;

  /// Historic (pre-2026-07) builds stored Khmer as `kh`, which is not a valid
  /// ISO 639-1 code and silently broke locale-aware behavior (e.g. the Khmer
  /// font never activated — `fontFamilyForLocale` matches `km`). Migrate the
  /// stored value transparently on first read.
  static const String _legacyKhmerCode = 'kh';
  static const String _khmerCode = 'km';

  @override
  String? getSavedLanguageCode() {
    final code = _prefs.savedLanguageCode;
    if (code == _legacyKhmerCode) {
      // Fire-and-forget: the migrated value is returned immediately either
      // way; persistence catches up in the background.
      _prefs.setLanguageCode(_khmerCode);
      return _khmerCode;
    }
    return code;
  }

  @override
  Future<void> saveLanguageCode(String code) => _prefs.setLanguageCode(code);
}
