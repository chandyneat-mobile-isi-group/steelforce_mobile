import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/routes/app_routes.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// The real typefaces, so layout checks measure what a phone draws — the
/// test font gives every glyph a square box, far wider than Source Sans 3.
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
  late _MockAuthBloc bloc;

  setUpAll(_loadFonts);

  setUp(() {
    bloc = _MockAuthBloc();
    whenListen(bloc, const Stream<AuthState>.empty(),
        initialState: const AuthInitialState());
  });

  tearDown(() => bloc.close());

  Future<void> pump(
    WidgetTester tester, {
    String lang = 'en',
    Size size = const Size(390, 844),
    bool dark = false,
    bool pushed = false,
  }) async {
    await tester.runAsync(() => LocalizationService.instance.load(lang));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget login() => BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const LoginScreen(),
        );

    await tester.pumpWidget(ScreenUtilInit(
      designSize: size.width < 600 ? const Size(390, 844) : size,
      builder: (context, _) => MaterialApp(
        theme: (dark ? AppTheme.dark : AppTheme.light)(lang == 'km'
            ? AppTypography.khmerFontFamily
            : AppTypography.latinFontFamily),
        localizationsDelegates: PhoneFieldLocalization.delegates,
        routes: {
          Static.main: (_) => const Scaffold(body: Text('SHELL')),
          Static.forgotPassword: (_) => const Scaffold(body: Text('FORGOT')),
        },
        home: pushed
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => login())),
                    child: const Text('HOME'),
                  ),
                ),
              )
            : login(),
      ),
    ));
    if (pushed) {
      await tester.pump();
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final (name, size) in [
    ('iPhone SE', const Size(375, 667)),
    ('iPhone 14', const Size(390, 844)),
    ('iPad', const Size(768, 1024)),
  ]) {
    for (final lang in ['en', 'km']) {
      for (final dark in [false, true]) {
        testWidgets(
            'lays out cleanly on $name ($lang, ${dark ? 'dark' : 'light'})',
            (tester) async {
          await pump(tester, lang: lang, size: size, dark: dark);
          expect(tester.takeException(), isNull);
          // Sign In fits on screen without scrolling.
          expect(tester.getRect(find.byType(GradientButton)).bottom,
              lessThanOrEqualTo(size.height));
        });
      }
    }
  }

  testWidgets('"Continue as Guest" goes back to where sign-in was asked for',
      (tester) async {
    await pump(tester, pushed: true);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('"Continue as Guest" opens the guest home when nothing is behind',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('"Forgot?" in the password field opens password reset',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Forgot?'));
    await tester.pumpAndSettle();
    expect(find.text('FORGOT'), findsOneWidget);
  });
}
