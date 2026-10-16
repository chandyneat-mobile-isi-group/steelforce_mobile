// Add this to app_routes.dart or a new file like navigator_key.dart
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// The app's one [ScaffoldMessengerState], kept across app restarts.
///
/// A language change or sign-out rebuilds `MaterialApp` under a new key. With
/// a messenger per `MaterialApp`, a snackbar still animating on the old one —
/// or a listener in a closing sheet that asked the old one to show something —
/// looked up a torn-down tree and threw "Looking up a deactivated widget's
/// ancestor is unsafe". One global key moves the same messenger into the new
/// app instead, and code that runs outside a live widget (stream listeners,
/// background results) can show a message through it without any lookup.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Route name constants. Plain strings — no framework dependency, so this
/// file is identical whether you use GetX or BLoC.
class Static {
  Static._();

  static const String splash = '/';
  static const String login = '/login';
  static const String main = '/main'; // MainShell (bottom-nav container)

  // Deep-link entry points into a single MainShell tab (e.g. from a push
  // notification) — not used by in-app navigation today, which stays on
  // MainShell's IndexedStack, but kept reachable via onGenerateRoute.
  static const String home = '/home';
  static const String lead = '/lead';
  static const String chooseLanguage = '/choose-language';
  // First-run only. Language selection leads here, and finishing or
  // skipping it flips `isOnboardingComplete`, after which splash routes
  // straight to the shell and this is never seen again.
  static const String onboarding = '/onboarding';
  static const String depot = '/depot';
  static const String profile = '/profile';
  static const String myVisits = '/my-visits';
  static const String order = '/order';
  static const String forgotPassword = '/forgot-password';
  static const String verifyOtp = '/verify-otp';
  static const String createNewPassword = '/create-new-password';
  static const String resetPasswordSuccess = '/reset-password-success';
  // After a sign-in with a temporary password. No way back to the shell
  // until the rep has set their own.
  static const String changeTemporaryPassword = '/change-temporary-password';
  static const String revenue = '/revenue';
}
