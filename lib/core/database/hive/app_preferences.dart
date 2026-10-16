import 'package:hive_flutter/hive_flutter.dart';

/// Non-sensitive app settings. Interface unchanged from the shared_preferences
/// version, so `app.dart` needs no edits — only the backing store swapped to
/// Hive. Hive stores bool/String natively (no JSON), so reads are fast.
abstract interface class AppPreferences {
  bool get isOnboardingComplete;
  Future<void> setOnboardingComplete({required bool value});

  String? get savedLanguageCode;
  Future<void> setLanguageCode(String code);

  /// Active theme mode as its stored string (`light`/`dark`/`system`), or null
  /// when the user has never chosen — callers default to Light.
  String? get savedThemeMode;
  Future<void> setThemeMode(String mode);

  /// Previously-selected theme mode string, if any.
  String? get lastThemeMode;
  Future<void> setLastThemeMode(String mode);

  /// Persisted theme-preferences schema version (future migrations).
  int get themeVersion;
  Future<void> setThemeVersion(int version);
}

class AppPreferencesImpl implements AppPreferences {
  const AppPreferencesImpl(this._box);
  final Box<dynamic> _box;

  static const String _kOnboarding = 'onboarding_complete';
  static const String _kLanguage = 'language_code';
  static const String _kThemeMode = 'theme_mode';
  static const String _kLastThemeMode = 'theme_mode_last';
  static const String _kThemeVersion = 'theme_version';

  @override
  bool get isOnboardingComplete =>
      _box.get(_kOnboarding, defaultValue: false) as bool;

  @override
  Future<void> setOnboardingComplete({required bool value}) =>
      _box.put(_kOnboarding, value);

  @override
  String? get savedLanguageCode => _box.get(_kLanguage) as String?;

  @override
  Future<void> setLanguageCode(String code) => _box.put(_kLanguage, code);

  @override
  String? get savedThemeMode => _box.get(_kThemeMode) as String?;

  @override
  Future<void> setThemeMode(String mode) => _box.put(_kThemeMode, mode);

  @override
  String? get lastThemeMode => _box.get(_kLastThemeMode) as String?;

  @override
  Future<void> setLastThemeMode(String mode) => _box.put(_kLastThemeMode, mode);

  @override
  int get themeVersion => _box.get(_kThemeVersion, defaultValue: 1) as int;

  @override
  Future<void> setThemeVersion(int version) =>
      _box.put(_kThemeVersion, version);
}
