import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/auth/login_required_dialog.dart';
import 'package:steelforce/core/session/session_manager.dart';

/// The single, reusable entry point for gating protected features behind a
/// signed-in session.
///
/// Guests can browse the whole app; the moment they try to use something that
/// needs an account (create order, cart, checkout, profile, history,
/// notifications, saved items, …) call [requireAuthentication]. It reads the
/// synchronous [SessionManager] (kept current by `AuthBloc`) and, for guests,
/// shows the [LoginRequiredDialog] — so the "are you allowed?" logic and the
/// prompt live in exactly one place instead of being copy-pasted per feature.
///
/// ```dart
/// if (await AuthGuard.requireAuthentication(context)) {
///   openCheckout();
/// }
/// // …or the ergonomic form:
/// await context.requireAuth(onAuthenticated: openCheckout);
/// ```
abstract final class AuthGuard {
  /// Whether a real session is active right now (synchronous, no `await`).
  static bool get isAuthenticated =>
      GetIt.instance<SessionManager>().isAuthenticated;

  /// Returns `true` when the user may proceed (already authenticated) and
  /// `false` when they were prompted to log in instead.
  ///
  /// When authenticated, [onAuthenticated] runs immediately. When a guest, the
  /// [LoginRequiredDialog] is shown; navigation to the login screen (on "Login
  /// Now") is handled by the dialog itself.
  static Future<bool> requireAuthentication(
    BuildContext context, {
    VoidCallback? onAuthenticated,
  }) async {
    if (isAuthenticated) {
      onAuthenticated?.call();
      return true;
    }
    if (!context.mounted) return false;
    await LoginRequiredDialog.show(context);
    return false;
  }
}

/// Ergonomic call site: `await context.requireAuth(onAuthenticated: …)`.
extension AuthGuardX on BuildContext {
  Future<bool> requireAuth({VoidCallback? onAuthenticated}) =>
      AuthGuard.requireAuthentication(this, onAuthenticated: onAuthenticated);
}
