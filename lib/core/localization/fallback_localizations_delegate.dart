import 'package:flutter/widgets.dart';

/// Wraps a third-party [LocalizationsDelegate] that does not cover every locale
/// the app ships, serving its English resources instead of leaving a gap.
///
/// ## Why this exists
///
/// `MaterialApp` checks, on every build, that *every* declared locale is
/// supported by *every* delegate. Flutter's own `GlobalMaterialLocalizations`
/// covers Khmer; `phone_form_field`'s `CountrySelectorLocalization` and
/// `PhoneFieldLocalizationImpl` do not. Declaring `km` therefore produced:
///
/// ```
/// Warning: This application's locale, km, is not supported by all of its
/// localization delegates.
/// • A CountrySelectorLocalization delegate that supports the km locale was not found.
/// ```
///
/// on every launch. The app still worked — the country picker fell back to
/// English on its own — but a permanent scary warning trains everyone to ignore
/// the console, which is how the *next* real localization warning gets missed.
///
/// The alternatives were worse. Dropping `km` from `supportedLocales` is what
/// caused the original bug (`Localizations.localeOf` silently resolves back to
/// English, so all master data renders Latin). Dropping the phone delegates
/// breaks the country picker. Translating a third-party package's strings is
/// not our code to own.
///
/// So this states the truth explicitly: *we know these strings are English in a
/// Khmer session, and that is accepted*. It is a declaration, not a workaround —
/// and if the package ever adds Khmer, [_inner] starts supporting `km` and this
/// wrapper stops substituting on its own, with no code change here.
class FallbackLocalizationsDelegate<T> extends LocalizationsDelegate<T> {
  const FallbackLocalizationsDelegate(this._inner,
      {Locale fallback = const Locale('en')})
      : _fallback = fallback;

  final LocalizationsDelegate<T> _inner;

  /// The locale whose resources stand in. English, because it is the one every
  /// such package ships and the one a Cambodian rep is second-most likely to
  /// read — a blank country picker would be unusable, an English one is not.
  final Locale _fallback;

  /// Claims every locale. That is the point: the wrapper's job is to guarantee
  /// [load] can always answer, so `MaterialApp`'s completeness check passes.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) =>
      _inner.load(_inner.isSupported(locale) ? locale : _fallback);

  /// Delegates the decision rather than returning a blanket `true`/`false`:
  /// reloading needlessly on every locale change would rebuild the country list
  /// for nothing, and never reloading would strand it on the first locale seen.
  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) =>
      old is! FallbackLocalizationsDelegate<T> || old._inner != _inner;

  @override
  String toString() => 'FallbackLocalizationsDelegate($_inner)';
}

/// Convenience for wrapping a package's whole delegate list.
Iterable<LocalizationsDelegate<dynamic>> withEnglishFallback(
  Iterable<LocalizationsDelegate<dynamic>> delegates,
) =>
    delegates.map(FallbackLocalizationsDelegate.new);
