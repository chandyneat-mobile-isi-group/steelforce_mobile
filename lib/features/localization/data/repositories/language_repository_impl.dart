import 'dart:ui' show PlatformDispatcher;

import 'package:steelforce/core/localization/language_manager.dart';
import 'package:steelforce/features/localization/data/datasources/language_local_datasource.dart';
import 'package:steelforce/features/localization/data/models/language_model.dart';
import 'package:steelforce/features/localization/domain/entities/language_entity.dart';
import 'package:steelforce/features/localization/domain/repositories/language_repository.dart';

/// [LanguageRepository] combining the persisted preference
/// ([LanguageLocalDatasource]) with the live translation store
/// ([LanguageManager]). Domain callers only ever see [LanguageEntity].
class LanguageRepositoryImpl implements LanguageRepository {
  const LanguageRepositoryImpl({
    required LanguageLocalDatasource datasource,
    required LanguageManager manager,
    List<String> Function() deviceLanguageCodes = _platformLanguageCodes,
  })  : _datasource = datasource,
        _manager = manager,
        _deviceLanguageCodes = deviceLanguageCodes;

  final LanguageLocalDatasource _datasource;
  final LanguageManager _manager;

  /// The phone's preferred languages, most preferred first.
  final List<String> Function() _deviceLanguageCodes;

  static List<String> _platformLanguageCodes() => [
        for (final l in PlatformDispatcher.instance.locales) l.languageCode,
      ];

  @override
  List<LanguageEntity> getSupportedLanguages() =>
      // Re-typed copy, not the raw List<LanguageModel>: callers use
      // `firstWhere(..., orElse: () => <LanguageEntity>)`, which throws at
      // runtime against a covariant List<LanguageModel>.
      List<LanguageEntity>.unmodifiable(LanguageModel.supported);

  /// The rep's choice when they made one; otherwise the first of the phone's
  /// languages the app ships, so a phone set to Khmer opens in Khmer on first
  /// launch. English when neither says anything usable.
  @override
  LanguageEntity getCurrentLanguage() {
    final saved = _datasource.getSavedLanguageCode();
    if (saved != null) return LanguageModel.fromCode(saved);
    for (final code in _deviceLanguageCodes()) {
      final match = LanguageModel.supported.where((l) => l.code == code);
      if (match.isNotEmpty) return match.first;
    }
    return LanguageModel.english;
  }

  @override
  Future<void> changeLanguage(String code) async {
    // Resolve through the catalog so an unknown code degrades to the default
    // instead of loading a nonexistent asset.
    final language = LanguageModel.fromCode(code);
    await _manager.apply(language.code);
    await _datasource.saveLanguageCode(language.code);
  }

  @override
  Future<void> restoreSavedLanguage() =>
      _manager.apply(getCurrentLanguage().code);
}
