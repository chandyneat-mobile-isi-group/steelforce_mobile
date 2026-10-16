import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_home_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_sign_in_button.dart';

/// The real typefaces, so "fits on one screen" measures what a phone
/// draws. The test font gives every glyph a square box — far wider than
/// Source Sans 3 — and would fail a layout that fits.
Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(Future.value(
          ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await family('Source Sans 3', [
    'english/Source_Sans_3/static/SourceSans3-Regular.ttf',
    'english/Source_Sans_3/static/SourceSans3-Medium.ttf',
    'english/Source_Sans_3/static/SourceSans3-SemiBold.ttf',
    'english/Source_Sans_3/static/SourceSans3-Bold.ttf',
  ]);
  await family('MiSans Khmer', [
    'khmer/MiSansKhmer-Regular.ttf',
    'khmer/MiSansKhmer-Medium.ttf',
    'khmer/MiSansKhmer-Bold.ttf',
  ]);
}

void main() {
  late int logins;

  setUpAll(_loadFonts);

  setUp(() => logins = 0);

  Future<void> pump(
    WidgetTester tester, {
    String lang = 'en',
    Size size = const Size(390, 844),
    double textScale = 1.0,
    bool dark = false,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await tester.runAsync(() => LocalizationService.instance.load(lang));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: size.width < 600 ? const Size(390, 844) : size,
      builder: (context, _) => MaterialApp(
        theme: (dark ? AppTheme.dark : AppTheme.light)(lang == 'km'
            ? AppTypography.khmerFontFamily
            : AppTypography.latinFontFamily),
        builder: (context, app) => MediaQuery(
          data: MediaQueryData(
              size: size,
              padding: padding,
              viewPadding: padding,
              textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: Scaffold(body: GuestHomeScreen(onLogin: () => logins++)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the brand, the pitch, the four areas and sign-in',
      (tester) async {
    await pump(tester);

    for (final text in [
      'Sales & Distribution',
      'Manage your sales visits, depots, quotations & orders.',
      'Visits',
      'Depots',
      'Quotations',
      'Orders',
      'Sign In',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.textContaining('Version '), findsOneWidget);
  });

  testWidgets('sign-in and every area open the login prompt', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(GuestSignInButton));
    for (final area in ['Visits', 'Depots', 'Quotations', 'Orders']) {
      await tester.tap(find.text(area));
    }
    expect(logins, 5);
  });

  for (final (name, size) in [
    ('360×640 small Android', const Size(360, 640)),
    ('390×844 iPhone', const Size(390, 844)),
    ('768×1024 iPad', const Size(768, 1024)),
    ('1024×768 iPad landscape', const Size(1024, 768)),
  ]) {
    for (final lang in ['en', 'km']) {
      for (final dark in [false, true]) {
        testWidgets(
            'lays out cleanly on $name ($lang, ${dark ? 'dark' : 'light'})',
            (tester) async {
          await pump(tester, lang: lang, size: size, dark: dark);
          expect(tester.takeException(), isNull);
          // The button is always reachable.
          expect(find.byType(GuestSignInButton), findsOneWidget);
        });
      }
    }
  }

  for (final (name, size, padding) in [
    (
      'iPhone 14',
      const Size(390, 844),
      const EdgeInsets.fromLTRB(0, 47, 0, 34)
    ),
    ('Android 412×915', const Size(412, 915), const EdgeInsets.only(top: 24)),
  ]) {
    for (final lang in ['en', 'km']) {
      testWidgets('fits one screen without scrolling on $name ($lang)',
          (tester) async {
        await pump(tester, lang: lang, size: size, padding: padding);
        expect(tester.takeException(), isNull);
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        expect(scroll.position.maxScrollExtent, 0);
        final button = tester.getRect(find.byType(GuestSignInButton));
        expect(button.bottom, lessThanOrEqualTo(size.height - padding.bottom));
      });
    }
  }

  testWidgets('holds together in Khmer at 200% text', (tester) async {
    await pump(tester, lang: 'km', textScale: 2.0);
    expect(tester.takeException(), isNull);
    // Scrolls rather than shrinking the rep's text back down.
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.ensureVisible(find.byType(GuestSignInButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GuestSignInButton));
    expect(logins, 1);
  });
}
