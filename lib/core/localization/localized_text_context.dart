import 'package:flutter/widgets.dart';
import 'package:steelforce/core/localization/localized_text.dart';

/// Renders master-data text in the language currently on screen.
///
/// Reads the locale from [Localizations], which `MaterialApp` drives from
/// `LanguageCubit`. That is what makes a language switch instant: the locale
/// changes, every widget below rebuilds, and each one re-resolves the text it
/// already holds. Nothing is re-fetched, re-parsed, or re-synced, because both
/// languages were already in the entity.
extension LocalizedTextContext on BuildContext {
  /// `'en'` / `'km'`.
  String get languageCode => Localizations.localeOf(this).languageCode;

  /// The active language's text for [text].
  String localized(LocalizedText text) => text.resolve(languageCode);

  /// Null-tolerant variant for optional fields like a category description.
  String? localizedOrNull(LocalizedText? text) => text?.resolve(languageCode);
}
