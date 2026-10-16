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
  })  : _datasource = datasource,
        _manager = manager;

  final LanguageLocalDatasource _datasource;
  final LanguageManager _manager;

  @override
  List<LanguageEntity> getSupportedLanguages() =>
      // Re-typed copy, not the raw List<LanguageModel>: callers use
      // `firstWhere(..., orElse: () => <LanguageEntity>)`, which throws at
      // runtime against a covariant List<LanguageModel>.
      List<LanguageEntity>.unmodifiable(LanguageModel.supported);

  @override
  LanguageEntity getCurrentLanguage() =>
      LanguageModel.fromCode(_datasource.getSavedLanguageCode());

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
