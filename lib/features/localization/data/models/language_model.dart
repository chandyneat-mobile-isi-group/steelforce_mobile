import 'package:steelforce/features/localization/domain/entities/language_entity.dart';

/// Data-layer representation of a supported language.
///
/// Also owns the **shipped catalog**: adding a language to the app is
/// (1) drop `assets/lang/<code>.json`, (2) add one entry to [supported],
/// (3) add its `language.<name>` / `language.<name>_region` keys to every
/// bundle. Nothing else in the app changes.
class LanguageModel extends LanguageEntity {
  const LanguageModel({
    required super.code,
    required super.nameKey,
    required super.regionKey,
    required super.flag,
  });

  /// Default language — used when nothing is saved or the saved code is
  /// unknown (e.g. a language removed in a later release).
  static const LanguageModel english = LanguageModel(
    code: 'en',
    nameKey: 'language.english',
    regionKey: 'language.english_region',
    flag: '🇺🇸',
  );

  static const LanguageModel khmer = LanguageModel(
    code: 'km',
    nameKey: 'language.khmer',
    regionKey: 'language.khmer_region',
    flag: '🇰🇭',
  );

  /// Display-ordered catalog of everything `assets/lang/` ships.
  static const List<LanguageModel> supported = [english, khmer];

  /// Resolves [code] against the catalog, falling back to [english].
  static LanguageModel fromCode(String? code) => supported.firstWhere(
        (l) => l.code == code,
        orElse: () => english,
      );
}
