import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/features/shell/presentation/widgets/demo_mode_badge.dart';
import 'package:steelforce/core/database/hive/app_preferences.dart';
import 'package:steelforce/core/localization/fallback_localizations_delegate.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';
import 'package:steelforce/core/session/app_restart_controller.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/localization/presentation/bloc/language_cubit.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_host.dart';
import 'package:steelforce/features/settings/theme/domain/entities/app_theme_mode.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_cubit.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_state.dart';
import 'package:steelforce/routes/app_page.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/shared/widgets/sync_notice_host.dart';

/// Replaces Material 3's default Android "stretch" overscroll (which visibly
/// grows/stretches content when scrolling past its bounds, even on screens
/// shorter than the viewport) with plain clamping — content stops at its
/// edges instead of bouncing/stretching, app-wide.
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

// app.dart

/// One-shot latch so the splash screen is used as the initial route only on the
/// very first build (cold boot). Language changes recreate [MaterialApp], which
/// re-runs the initial-route resolver — without this, those rebuilds could
/// replay the splash. Module-private and set exactly once for the process.
bool _splashShown = false;

/// The locales `MaterialApp` will actually resolve to.
///
/// Must stay in step with `LanguageModel.supported` and the `assets/lang/*.json`
/// bundles: a language offered in the picker but missing here resolves back to
/// English, and the only visible symptom is master data quietly staying Latin.
///
/// Public so `test/core/localization/locale_resolution_test.dart` can assert
/// against the *real* list rather than a copy — a copied list would keep
/// passing after someone edited this one, which is precisely the failure mode
/// that test exists to catch.
const List<Locale> kSupportedLocales = [Locale('en'), Locale('km')];

/// Wired per the setup note in
/// `features/authentication/.../forgot_password/identifier_field.dart`:
/// `phone_form_field`'s country picker throws "no MaterialLocalizations found"
/// without its delegate, and the Material/Widgets/Cupertino delegates are what
/// give Flutter's own widgets (date picker, text-selection menu) Khmer copy.
///
/// Public for the same reason as [kSupportedLocales].
///
/// The phone-field delegates are wrapped because that package ships no Khmer —
/// see [FallbackLocalizationsDelegate]. Flutter's own three cover `km` natively
/// and are passed straight through.
final List<LocalizationsDelegate<dynamic>> kLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  ...withEnglishFallback(PhoneFieldLocalization.delegates),
];

class ISISteelSalesApp extends StatelessWidget {
  const ISISteelSalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              GetIt.instance<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider.value(value: GetIt.instance<LanguageCubit>()),
        BlocProvider.value(value: GetIt.instance<ThemeCubit>()),
      ],
      // Navigation is intentionally *not* driven from a global auth listener.
      // Each surface owns its own transition — Splash routes on boot, the login
      // form advances on success, and logout returns to the shell as a guest —
      // which keeps guests from being yanked around and avoids duplicate
      // redirects. This root only decides the *initial* route on (re)build.
      // ── Responsive scaling ────────────────────────────────────────────────
      //
      // `flutter_screenutil` scales every `.w`/`.h`/`.sp` in the app by
      // `screenWidth / designSize.width`. Against the 390pt phone design that
      // is exactly right on a phone and catastrophic in a browser: a 1920px
      // window multiplies every padding, radius, and font size by ~4.9.
      //
      // Rather than edit the ~43 files that use those extensions, the design
      // size itself becomes responsive:
      //
      //   • compact (< 600) → 390×844, the untouched mobile baseline. Scaling
      //     behaves exactly as before, so phone rendering is bit-identical.
      //   • wider          → the real viewport, which makes the scale factor
      //     1.0. `16.w` then means 16 logical pixels, and the layout is driven
      //     by breakpoints and constraints instead of a multiplier.
      //
      // This is the whole reason the desktop layout is readable, and it is one
      // place rather than several hundred call sites.
      child: LayoutBuilder(
        builder: (context, constraints) => ScreenUtilInit(
          designSize: Breakpoints.fromWidth(constraints.maxWidth).isCompact
              ? const Size(390, 844)
              : Size(constraints.maxWidth, constraints.maxHeight),
          // Full "restart" on language change: the ValueKey below is rebuilt
          // with the new language code, which tears down and recreates the
          // entire MaterialApp/Navigator so every screen — and all the data it
          // loads — comes back up in the freshly selected language. Signed-in
          // users and guests land straight back on the shell (not the splash)
          // via the auth-aware initial route.
          builder: (context, child) => BlocBuilder<LanguageCubit, Locale>(
            builder: (context, locale) => ValueListenableBuilder<int>(
              // Sign-out bumps this, which changes the key below and rebuilds
              // the whole app — see [AppRestartController]. Nested inside the
              // language builder so the two compose: either can restart the
              // app, neither cancels the other.
              valueListenable: GetIt.instance<AppRestartController>(),
              builder: (context, restartGeneration, _) {
                final authState = context.read<AuthBloc>().state;
                final initialRoute = _resolveInitialRoute(authState);
                final fontFamily = AppTypography.fontFamilyForLocale(locale);
                // Only the theme *mode* drives this rebuild — the two ThemeData
                // objects themselves are cached in AppTheme, so switching light
                // ⇄ dark never re-derives a theme and the whole app restyles in
                // one frame with no restart.
                return BlocSelector<ThemeCubit, ThemeState, AppThemeMode>(
                  selector: (state) => state.mode,
                  builder: (context, themeMode) {
                    return MaterialApp(
                      // Both a language change and a sign-out restart the app by
                      // changing this key.
                      key: ValueKey(
                          'lang_${locale.languageCode}_r$restartGeneration'),
                      navigatorKey: navigatorKey, // Assign the key here
                      // One messenger across restarts — see [rootMessengerKey].
                      scaffoldMessengerKey: rootMessengerKey,
                      onGenerateTitle: (_) => 'app.title'.tr,
                      debugShowCheckedModeBanner: false,
                      scrollBehavior: _AppScrollBehavior(),
                      theme: AppTheme.light(fontFamily),
                      darkTheme: AppTheme.dark(fontFamily),
                      themeMode: _materialThemeMode(themeMode),
                      locale: locale,
                      // `locale:` alone does NOT make `Localizations.localeOf`
                      // return Khmer. MaterialApp *resolves* the requested
                      // locale against `supportedLocales`, which defaults to
                      // `[Locale('en','US')]` when unset — so `Locale('km')`
                      // fell straight back to English.
                      //
                      // That produced the exact split this app shipped with:
                      // every `'key'.tr` label was Khmer (the String extension
                      // reads a global singleton and never consults
                      // `Localizations`), while every piece of master data
                      // resolved through `context.localized(...)` came out
                      // English — because it asks `Localizations.localeOf`,
                      // which was still saying `en`. Chrome translated, data
                      // not: the bug looked like missing Khmer *data* and was
                      // really a missing three-line locale declaration.
                      supportedLocales: kSupportedLocales,
                      localizationsDelegates: kLocalizationsDelegates,
                      initialRoute: initialRoute,
                      // Build the initial route as a single page (avoids Flutter's
                      // default '/'-splitting pulling in a not-found parent route).
                      onGenerateInitialRoutes: (name) =>
                          [AppPages.onGenerateRoute(RouteSettings(name: name))],
                      onGenerateRoute: AppPages.onGenerateRoute,
                      // Push starts here rather than in `AppBootstrapService`.
                      // Two of its steps need what boot does not have yet: the
                      // loaded language bundle (Android caches a notification
                      // channel's name at creation and ignores later renames, so
                      // the first launch permanently decides them) and a
                      // Navigator for a tapped notification. See
                      // [NotificationHost].
                      //
                      // `builder` wraps the Navigator, so this sits above every
                      // route and survives navigation — which is what a
                      // background push arriving mid-session needs.
                      builder: (context, child) => SyncNoticeHost(
                        messengerKey: rootMessengerKey,
                        engine: GetIt.instance.isRegistered<SyncEngine>()
                            ? GetIt.instance<SyncEngine>()
                            : null,
                        connectivity:
                            GetIt.instance.isRegistered<ConnectivityService>()
                                ? GetIt.instance<ConnectivityService>()
                                : null,
                        child: NotificationHost(
                          // TODO(release-gate): a pass-through outside demo
                          // builds. Above the Navigator so the DEMO badge is
                          // on every route, sign-in included.
                          child: DemoModeOverlay(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Resolves the route the freshly-built [MaterialApp]/Navigator should open
  /// on. Called on cold boot and again on every language change (which rebuilds
  /// the app), so it must be stable and idempotent:
  ///
  ///  • an authenticated user or a guest who has finished onboarding goes
  ///    straight to the shell — no splash replay when they switch languages
  ///    mid-session;
  ///  • the very first cold boot shows the splash exactly once (it then routes
  ///    on onboarding status);
  ///  • later rebuilds before onboarding is done reopen language selection
  ///    directly, so toggling a language on that screen never flashes splash.
  String _resolveInitialRoute(AuthState authState) {
    // A session restored with a temporary password still in force goes back
    // to the change-password screen, not the shell.
    if (authState is AuthenticatedState && authState.passwordChangeRequired) {
      return Static.changeTemporaryPassword;
    }
    final onboarded = GetIt.instance<AppPreferences>().isOnboardingComplete;
    final resolved =
        authState is AuthenticatedState || authState is AuthGuestState;
    if (onboarded && resolved) return Static.main;
    if (!_splashShown) {
      _splashShown = true;
      return Static.splash;
    }
    return onboarded ? Static.main : Static.chooseLanguage;
  }

  /// Maps the app's [AppThemeMode] onto Flutter's [ThemeMode]. `system` is
  /// modelled and persisted today; `MaterialApp` already honours it via the
  /// provided `theme`/`darkTheme` pair, so surfacing it in the UI later needs
  /// no further wiring here.
  ThemeMode _materialThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };
}
