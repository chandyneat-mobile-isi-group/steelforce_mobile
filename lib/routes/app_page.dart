import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_ownership_reset_repository.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_remembered_phone.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/features/authentication/presentation/bloc/phone_password_change_cubit.dart';
import 'package:steelforce/features/authentication/presentation/phone_verification_messages.dart';
import 'package:steelforce/features/authentication/presentation/screens/change_temporary_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/phone_password_change_flow.dart';
import 'package:steelforce/features/authentication/presentation/screens/create_new_password_screen.dart';
import 'package:steelforce/features/profile/domain/usecases/change_password.dart';
import 'package:steelforce/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/success_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_otp_args.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_screen.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plan_calendar_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_plans_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/visit_plans_screen.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/screens/profile_screen.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/features/notification/presentation/screen/notification_preferences_screen.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_screen.dart';
import 'package:steelforce/features/onboarding/presentation/onboarding_screen.dart';
import 'package:steelforce/shared/widgets/coming_soon.dart';
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
          AppConfig.ordersComingSoon
              ? ComingSoonScreen(appBarTitle: 'orders.title'.tr)
              : const OrderScreen(),
          settings,
        );

      case Static.myVisits:
        return _page(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => GetIt.instance<VisitPlansCubit>()),
              BlocProvider(
                  create: (_) => GetIt.instance<VisitPlanCalendarCubit>()),
            ],
            child: const VisitPlansScreen(),
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
              // Reset is exclusively Firebase phone verification backed by
              // App Check and the server's rate-limit gate run before Firebase
              // is allowed to request an SMS.
              //
              // Deliberately does **not** navigate: `ForgotPasswordScreen`
              // already pushes `Static.verifyOtp` itself, tagged
              // `VerifyOtpArgs.passwordReset`, once this returns success. A
              // second push here — with a bare `String` argument the route no
              // longer accepts — double-navigated and crashed on the
              // `as VerifyOtpArgs?` cast.
              onSubmit: (identifier) async {
                if (_resetViaFirebase) {
                  // The repository asks the server to authorize the SMS first.
                  final result = await sl<PhoneOwnershipResetRepository>()
                      .sendResetCode(identifier);
                  return result.when(
                    success: (handle) =>
                        ForgotPasswordResult.success(phoneVerification: handle),
                    failure: (f) {
                      final limited = _isRateLimited(f);
                      return ForgotPasswordResult.failure(
                        limited
                            ? 'auth.rate_limit_message'.tr
                            : f is AuthenticationFailure &&
                                    (f.code?.startsWith(phoneFailurePrefix) ??
                                        false)
                                ? 'auth.reset_phone_neutral'.tr
                                : _phoneResetMessage(f),
                        cooldown: _rateLimitWait(f),
                      );
                    },
                  );
                }
                return ForgotPasswordResult.failure(
                  'auth.phone_verification_unavailable'.tr,
                );
              },
              onBackToLogin: () => Navigator.of(context).pop(),
            ),
          ),
          settings,
        );
      case Static.createNewPassword:
        // Carried from Firebase ID-token verification: the one-time reset
        // token and password policy returned by the backend.
        final grant = settings.arguments as PasswordResetGrant?;
        return _page(
          Builder(
            builder: (context) => CreateNewPasswordScreen(
              policy: grant?.policy,
              onSubmit: (newPassword) async {
                debugTrace('password-reset.ui', 'new password submitted');
                final result =
                    await GetIt.instance<AuthRepository>().resetPassword(
                  resetToken: grant?.resetToken ?? '',
                  newPassword: newPassword,
                );
                return result.when(
                  success: (_) {
                    debugTrace('password-reset.ui',
                        'backend password reset succeeded');
                    return const ResetPasswordResult.success();
                  },
                  failure: (f) {
                    debugTrace(
                        'password-reset.ui', 'backend password reset failed');
                    return ResetPasswordResult.failure(f.userMessage);
                  },
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
                    f is NetworkFailure
                        ? 'common.no_connection'.tr
                        : f.userMessage,
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

      case Static.changePasswordByPhone:
        // The cubit holds the phone proof; closing it with the route drops
        // the proof when the rep leaves at any step.
        return _page(
          BlocProvider(
            create: (_) =>
                sl<PhonePasswordChangeCubit>(param1: _resetViaFirebase),
            child: const PhonePasswordChangeFlow(),
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
              showCoachMascot: true,
              onContinue: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil(Static.login, (route) => false),
            ),
          ),
          settings,
        );
      case Static.verifyOtp:
        // Password reset OTPs are verified by Firebase. The backend receives
        // only the resulting Firebase ID token at phone/verify.
        final args = settings.arguments as VerifyOtpArgs?;
        if (args == null) {
          return _page(_NotFound(name: settings.name), settings);
        }
        final firebaseSession = args.phoneVerification;
        if (firebaseSession == null || !_resetViaFirebase) {
          return _page(_NotFound(name: settings.name), settings);
        }
        return _firebaseVerifyOtp(args.target, firebaseSession, settings);
      default:
        return _page(_NotFound(name: settings.name), settings);
    }
  }

  /// Password reset sends its code through Firebase rather than the backend.
  /// Never on web, which has no Firebase app in this build (ADR-010).
  static bool get _resetViaFirebase =>
      AppConfig.passwordResetViaFirebase && !kIsWeb;

  /// Step 2 on the Firebase path: Firebase confirms the code, the backend
  /// trades Firebase's proof for a one-time reset grant.
  static Route<dynamic> _firebaseVerifyOtp(
    String target,
    PhoneVerificationHandle session,
    RouteSettings settings,
  ) {
    // Outside the builder so a language-change rebuild keeps them. A resend
    // replaces the session: only the newest code can be confirmed.
    var handle = session;
    PasswordResetGrant? grant;
    return _page(
      Builder(
        builder: (context) => VerifyScreen(
          target: target,
          // Android verified the number with no SMS — nothing to type.
          autoVerify: session.isVerified,
          automaticProofAvailable: session.automaticProof,
          showVerifyButton: false,
          onVerify: (code) async {
            final repository = sl<PhoneOwnershipResetRepository>();
            if (AppConfig.firebasePhoneCheckOnly) {
              final result =
                  await repository.confirmOwnership(handle: handle, otp: code);
              return result.when(
                success: (_) => const VerifyResult.success(),
                failure: (f) => VerifyResult.failure(_phoneResetMessage(f)),
              );
            }
            final result =
                await repository.verifyResetCode(handle: handle, otp: code);
            return result.when(
              success: (g) {
                grant = g;
                return const VerifyResult.success();
              },
              failure: (f) => VerifyResult.failure(_phoneResetMessage(f)),
            );
          },
          onVerified: (_) {
            if (AppConfig.firebasePhoneCheckOnly) {
              // TODO(release-gate): debug check-only mode — ends the flow once
              // Firebase confirms the code. Developer-facing, so not localised;
              // unreachable in release (`kReleaseMode`).
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                  'DEBUG: Firebase verified this phone. '
                  'Backend exchange skipped (FIREBASE_PHONE_CHECK_ONLY).',
                ),
              ));
              Navigator.of(context).maybePop();
              return;
            }
            Navigator.of(context).pushReplacementNamed(
              Static.createNewPassword,
              arguments: grant,
            );
          },
          onResend: () async {
            final result = await sl<PhoneOwnershipResetRepository>()
                .sendResetCode(handle.phoneNumber, previous: handle);
            return result.when(
              success: (data) {
                handle = data;
                return ResendResult.sent(
                  cooldown: Duration(seconds: data.resendAfter),
                );
              },
              failure: (f) => ResendResult.failure(
                _isRateLimited(f)
                    ? 'auth.rate_limit_message'.tr
                    : _phoneResetMessage(f),
                cooldown: _rateLimitWait(f),
              ),
            );
          },
          resendCooldown: Duration(seconds: session.resendAfter),
          onBackToLogin: () => Navigator.of(context).maybePop(),
        ),
      ),
      settings,
    );
  }

  /// The backend refused for rate: honour its `Retry-After`.
  static bool _isRateLimited(Failure f) =>
      f is ServerFailure &&
      (f.statusCode == 429 || f.code == ApiErrorCodes.tooManyRequests);

  /// The server's interval when [f] is a rate limit, else null. Falls back to
  /// a minute when the server named none.
  static Duration? _rateLimitWait(Failure f) => _isRateLimited(f)
      ? (f as ServerFailure).retryAfter ?? const Duration(seconds: 60)
      : null;

  /// The rep-facing message for a failure on the Firebase reset path.
  /// Firebase failures arrive as codes and are localised here; a failure from
  /// the backend exchange keeps the backend's message, as on the SMS path.
  static String _phoneResetMessage(Failure f) {
    if (f is NetworkFailure) return 'auth.phone_no_connection'.tr;
    final code = f is AuthenticationFailure ? f.code : null;
    return firebasePhoneMessage(code) ?? f.userMessage;
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
