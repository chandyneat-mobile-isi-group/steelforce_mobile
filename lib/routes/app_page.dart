import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/order/presentation/screens/quotes_coming_soon_screen.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_remembered_phone.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/authentication/presentation/screens/change_temporary_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/create_new_password_screen.dart';
import 'package:steelforce/features/profile/domain/usecases/change_password.dart';
import 'package:steelforce/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/success_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_otp_args.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_screen.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/events/active_route_event.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_dashboard/stop_dashboard_screen.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/screens/profile_screen.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/features/notification/presentation/screen/notification_preferences_screen.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_screen.dart';
import 'package:steelforce/features/onboarding/presentation/onboarding_screen.dart';
import 'package:steelforce/features/splash/presentation/language_selection_screen.dart';
import 'package:steelforce/routes/app_routes.dart';

// Screens
import 'package:steelforce/features/splash/presentation/splash_screen.dart';
import 'package:steelforce/features/shell/presentation/main_shell.dart';
import 'package:steelforce/features/order/presentation/screens/order_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/login_screen.dart';

/// Flow: splash (6s) -> login -> (on success) -> main shell.
class AppPages {
  AppPages._();

  // app_page.dart
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Static.splash:
        return _page(const SplashScreen(), settings);

      case Static.login:
        // REMOVED BlocProvider here. It is now provided at the root.
        return _page(
          LoginScreen(getRememberedPhone: sl<GetRememberedPhone>()),
          settings,
        );

      case Static.main:
        return _page(const MainShell(), settings);

      case Static.order:
        return _page(
            FeatureFlags.quotesAndOrders
                ? const OrderScreen()
                : const QuotesComingSoonScreen(),
            settings);

      case Static.myVisits:
        return _page(
          MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => GetIt.instance<ActiveRouteBloc>()
                  ..add(const ActiveRouteLoadRequested('routeId')),
              ),
              BlocProvider(
                create: (_) => GetIt.instance<LocationTrackingCubit>(),
              ),
              BlocProvider(
                create: (_) => GetIt.instance<VisitCubit>(),
              ),
            ],
            child: const StopDashboardScreen(),
          ),
          settings,
        );

      case Static.chooseLanguage:
        return _page(const LanguageSelectionScreen(), settings);

      case Static.onboarding:
        return _page(const OnboardingScreen(), settings);

      // The notification inbox as a real route, not only a bottom sheet.
      //
      // `app://notifications` is §11's fallback for **every** unroutable deep
      // link — an event that names no single record, and any URI pointing at a
      // screen this build does not have yet. A cold start from a notification
      // tap has nothing underneath to raise a sheet over, so that fallback needs
      // a route with a back button.
      case NotificationDeepLink.inboxRoute:
        return _page(
          // Tapping a row routes on its own `deep_link` — the backend builds
          // those (§11), so this hands the link straight back to the resolver
          // rather than deriving a destination from the entity fields.
          NotificationsScreen(
            onOpenNotification: (notification) =>
                sl<NotificationCoordinator>().openLink(notification.deepLink),
          ),
          settings,
        );

      case NotificationDeepLink.notificationSettingsRoute:
        return _page(const NotificationPreferencesScreen(), settings);

      case Static.profile:
        return _page(
          BlocProvider(
            create: (_) => sl<ProfileCubit>(),
            child: const ProfileScreen(),
          ),
          settings,
        );
      case Static.forgotPassword:
        return _page(
          Builder(
            builder: (context) => ForgotPasswordScreen(
              // Step 1 of the SMS reset: `forgot-password/request` with
              // `recoveryMethod: "phone"`.
              //
              // Deliberately does **not** navigate: `ForgotPasswordScreen`
              // already pushes `Static.verifyOtp` itself, tagged
              // `VerifyOtpArgs.passwordReset`, once this returns success. A
              // second push here — with a bare `String` argument the route no
              // longer accepts — double-navigated and crashed on the
              // `as VerifyOtpArgs?` cast.
              onSubmit: (identifier) async {
                final result = await GetIt.instance<AuthRepository>()
                    .forgotPassword(identifier);
                return result.when(
                  // `forgot-password` always answers success, whether or not
                  // the address exists — reporting otherwise turns the
                  // endpoint into an account-enumeration oracle.
                  success: (_) => const ForgotPasswordResult.success(),
                  failure: (f) => ForgotPasswordResult.failure(f.message),
                );
              },
              onBackToLogin: () => Navigator.of(context).pop(),
            ),
          ),
          settings,
        );
      case Static.createNewPassword:
        // Carried from VerifyScreen: the grant `forgot-password/verify-otp`
        // issued once the SMS code checked out — the one-time reset token and
        // the password policy the new password is checked against.
        final grant = settings.arguments as PasswordResetGrant?;
        return _page(
          Builder(
            builder: (context) => CreateNewPasswordScreen(
              policy: grant?.policy,
              onSubmit: (newPassword) async {
                final result =
                    await GetIt.instance<AuthRepository>().resetPassword(
                  resetToken: grant?.resetToken ?? '',
                  newPassword: newPassword,
                );
                return result.when(
                  success: (_) => const ResetPasswordResult.success(),
                  failure: (f) => ResetPasswordResult.failure(f.message),
                );
              },
              onSuccess: () => Navigator.of(context).pushReplacementNamed(
                Static.resetPasswordSuccess,
              ),
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          settings,
        );

      case Static.changeTemporaryPassword:
        // The temporary password the rep just typed at sign-in, so they are
        // not asked for it twice. Held in memory for the life of this route
        // only, never persisted. Null on a cold start, and the screen then
        // asks for it.
        final temporaryPassword = settings.arguments as String?;
        return _page(
          Builder(
            builder: (context) => ChangeTemporaryPasswordScreen(
              currentPassword: temporaryPassword,
              onSubmit: (currentPassword, newPassword) async {
                final result = await sl<ChangePassword>()(
                  ChangePasswordParams(
                    currentPassword: currentPassword,
                    newPassword: newPassword,
                  ),
                );
                return result.when(
                  success: (_) => const ResetPasswordResult.success(),
                  failure: (f) => ResetPasswordResult.failure(
                    f is NetworkFailure ? 'common.no_connection'.tr : f.message,
                  ),
                );
              },
              onSuccess: () {
                context.read<AuthBloc>().add(const PasswordChangeCompleted());
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(Static.main, (route) => false);
              },
              onSignOut: () =>
                  context.read<AuthBloc>().add(const LogoutRequested()),
            ),
          ),
          settings,
        );

      case Static.resetPasswordSuccess:
        return _page(
          Builder(
            builder: (context) => SuccessScreen(
              title: 'auth.reset_password_success_title'.tr,
              subtitle: 'auth.reset_password_success_subtitle'.tr,
              buttonLabel: 'auth.back_to_login'.tr,
              onContinue: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil(Static.login, (route) => false),
            ),
          ),
          settings,
        );
      case Static.verifyOtp:
        // Password reset, step 2 — the only flow with a code screen. The code
        // is checked against `forgot-password/verify-otp`, which answers with
        // a one-time reset token; the new-password screen spends it at step 3.
        final args = settings.arguments as VerifyOtpArgs?;
        if (args == null) {
          return _page(_NotFound(name: settings.name), settings);
        }
        PasswordResetGrant? grant;
        return _page(
          Builder(
            builder: (context) => VerifyScreen(
              target: args.target,
              onVerify: (code) async {
                final result = await GetIt.instance<AuthRepository>()
                    .verifyResetCode(phoneNumber: args.target, otp: code);
                return result.when(
                  success: (g) {
                    grant = g;
                    return const VerifyResult.success();
                  },
                  failure: (f) => VerifyResult.failure(f.message),
                );
              },
              onVerified: (_) => Navigator.of(context).pushReplacementNamed(
                Static.createNewPassword,
                arguments: grant,
              ),
              // Resend is the step-1 request again; the server applies its own
              // cooldown and hourly limit, and only the newest code counts.
              onResend: () async {
                await GetIt.instance<AuthRepository>()
                    .forgotPassword(args.target);
              },
              onBackToLogin: () => Navigator.of(context).maybePop(),
            ),
          ),
          settings,
        );
      default:
        return _page(_NotFound(name: settings.name), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(
      Widget child, RouteSettings settings) {
    // Wrap every named route so its whole subtree (including MainShell and its
    // five tabs) rebuilds live when the language changes — the "hot reload"
    // localization effect, applied app-wide from one place.
    return MaterialPageRoute<dynamic>(
      builder: (_) => LocalizedBuilder(builder: (_) => child),
      settings: settings,
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('app.not_found'.tr)),
      body: Center(
          child: Text('app.no_route'.trParams({'name': name ?? '(null)'}))),
    );
  }
}
