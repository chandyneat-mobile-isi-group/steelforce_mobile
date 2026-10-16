import 'package:steelforce/features/localization/domain/entities/language_entity.dart';

/// Boundary for everything language-related: the supported catalog, the
/// persisted selection, and applying a language to the running app.
///
/// Mirrors [ThemeRepository]'s contract shape: reads are **synchronous** so the
/// saved language is available before the first frame (no wrong-language
/// flash on startup); writes/applies are async.
abstract interface class LanguageRepository {
  /// Languages the app ships translations for, in display order.
  List<LanguageEntity> getSupportedLanguages();

  /// The active language, restored from storage. Falls back to English when
  /// nothing has been saved or the saved code is no longer supported.
  LanguageEntity getCurrentLanguage();

  /// Loads [code]'s translation bundle into the live UI **and** persists the
  /// choice so it survives restarts. Unsupported codes are ignored.
  Future<void> changeLanguage(String code);

  /// Re-applies the persisted language on startup **without** rewriting the
  /// stored preference. Safe to call before any UI is built.
  Future<void> restoreSavedLanguage();
}
