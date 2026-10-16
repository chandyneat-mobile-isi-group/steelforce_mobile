import 'package:equatable/equatable.dart';

/// A display language the app can render its UI in.
///
/// Pure domain value — no Flutter, no storage detail. [code] is the ISO 639-1
/// language code (`en`, `km`, `zh`) and is the single identifier used for
/// persistence, asset lookup (`assets/lang/<code>.json`), and `Locale`.
class LanguageEntity extends Equatable {
  const LanguageEntity({
    required this.code,
    required this.nameKey,
    required this.regionKey,
    required this.flag,
  });

  /// ISO 639-1 code — `en`, `km`, `zh`.
  final String code;

  /// Localization key resolving to the language's **own** name
  /// (e.g. "English", "ភាសាខ្មែរ", "中文") — always rendered in that language
  /// so users can find theirs even when the UI shows the wrong one.
  final String nameKey;

  /// Localization key resolving to the region/context line shown under the
  /// name (e.g. "United States", "Cambodia", "China").
  final String regionKey;

  /// Flag emoji shown in selectors.
  final String flag;

  @override
  List<Object?> get props => [code, nameKey, regionKey, flag];
}
