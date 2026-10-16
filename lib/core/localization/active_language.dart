import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text.dart';

/// The active language, readable without a `BuildContext`.
///
/// Rendering master data normally goes through
/// [LocalizedTextContext.localized], which reads the locale from
/// [Localizations] and is what makes a language switch a plain rebuild. But
/// some code that must be language-aware has no context and never will:
///
///  * **search and sort** run in a cubit or a repository — a rep sorting the
///    depot directory alphabetically in Khmer expects Khmer collation order,
///    and that decision happens before any widget exists;
///  * **background surfaces** (the route-tracking foreground notification,
///    generated PDFs) render outside the widget tree entirely.
///
/// Those call sites used to either hardcode English or thread a locale
/// parameter through three layers. Both are worse than reading the one value
/// the app already keeps globally: [LocalizationService] is a singleton
/// precisely so `'key'.tr` can work anywhere, and this exposes the same fact
/// for master data.
///
/// **Do not use this inside `build()`.** It is a plain read with no dependency
/// registered, so a widget resolving through it will not rebuild when the
/// language changes — use `context.localized(...)` there, which will.
class ActiveLanguage {
  const ActiveLanguage._();

  /// `'en'` / `'km'`.
  static String get code => LocalizationService.instance.currentLanguageCode;

  static bool get isKhmer => code == 'km';

  /// The active language as a BCP 47 tag, for the `Accept-Language` header
  /// every API request carries.
  ///
  /// The server localises `shopName`, `statusDisplay` and every `message`
  /// against this, so it is what decides whether a Khmer-speaking rep reads
  /// Khmer. Region subtags are included because the API documents `km-KH` and
  /// `en-US` specifically; a bare `km` falls through its resolution chain to
  /// the platform default.
  static String get acceptLanguageTag => isKhmer ? 'km-KH' : 'en-US';

  /// [text] in the active language. The context-free twin of
  /// `context.localized(text)`.
  static String resolve(LocalizedText text) => text.resolve(code);

  /// Null-tolerant [resolve], for optional master-data fields.
  static String? resolveOrNull(LocalizedText? text) => text?.resolve(code);
}
