import 'package:flutter/material.dart';
import 'package:steelforce/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';

/// Pins the wiring that makes `context.localized(...)` actually see Khmer.
///
/// ## The bug this exists to prevent
///
/// `MaterialApp` does not take `locale:` at face value — it *resolves* it
/// against `supportedLocales`, which defaults to `[Locale('en','US')]` when the
/// app never declares one. Passing `Locale('km')` to an app with no
/// `supportedLocales` therefore yields `Localizations.localeOf(context) == en`.
///
/// That is silent and it splits the app in two:
///
///  * `'key'.tr` keeps working — the String extension reads a global singleton
///    and never consults `Localizations`. All UI chrome turns Khmer.
///  * `context.localized(entity.displayName)` returns **English** — it asks
///    `Localizations.localeOf`, which is still saying `en`.
///
/// The result reads as "the Khmer master data isn't coming through", sending
/// you to hunt through generators, assets and sync paths — when the actual
/// cause is three missing lines on `MaterialApp`. Nothing throws, nothing logs,
/// and it is invisible to anyone testing in English.
void main() {
  // The app's real list, imported rather than copied.
  const supportedLocales = kSupportedLocales;

  const text =
      LocalizedText(en: 'Palm Profile Roofing', km: 'ស័ង្កសី ផាម ភ្លី');

  Future<String> resolvedUnder(
    WidgetTester tester, {
    required Locale locale,
    required List<Locale> supported,
  }) async {
    late String seen;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: supported,
      localizationsDelegates: kLocalizationsDelegates,
      home: Builder(builder: (context) {
        seen = context.localized(text);
        return const SizedBox.shrink();
      }),
    ));
    return seen;
  }

  testWidgets('km renders Khmer when the app declares km as supported',
      (tester) async {
    expect(
      await resolvedUnder(tester,
          locale: const Locale('km'), supported: supportedLocales),
      'ស័ង្កសី ផាម ភ្លី',
    );
  });

  testWidgets('en still renders English', (tester) async {
    expect(
      await resolvedUnder(tester,
          locale: const Locale('en'), supported: supportedLocales),
      'Palm Profile Roofing',
    );
  });

  // The negative control — this is the exact misconfiguration that shipped.
  // If this ever starts returning Khmer, Flutter changed its fallback rule and
  // the guard above can be relaxed.
  testWidgets('an app that omits km falls back to English despite locale: km',
      (tester) async {
    expect(
      await resolvedUnder(tester,
          locale: const Locale('km'), supported: const [Locale('en')]),
      'Palm Profile Roofing',
      reason: 'MaterialApp resolves `locale` against `supportedLocales`; a '
          'locale that is not declared silently falls back to the first one',
    );
  });
}
