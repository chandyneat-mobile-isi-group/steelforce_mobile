import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/routes/app_routes.dart';

/// The outcome of a [LoginRequiredDialog].
enum LoginPromptResult {
  /// The user chose to sign in — the caller has been routed to login.
  login,

  /// The user dismissed the prompt (tapped "Later", scrimmed, or backed out)
  /// and stays where they were, still browsing as a guest.
  dismissed,
}

/// A premium, Material 3 "Login Required" prompt for guest users who reach a
/// protected feature.
///
/// Fully theme-aware (light/dark via [ColorScheme] + [AppThemeColors]),
/// responsive (width-capped and scroll-safe on small screens), and animated
/// (a soft fade + scale-in). Present it through [AuthGuard] rather than calling
/// it directly, so the auth check and the prompt stay in one place.
class LoginRequiredDialog extends StatelessWidget {
  const LoginRequiredDialog({super.key});

  /// Shows the dialog and resolves once dismissed. On "Login Now" it routes to
  /// the login screen and resolves with [LoginPromptResult.login]; otherwise
  /// [LoginPromptResult.dismissed].
  static Future<LoginPromptResult> show(BuildContext context) async {
    final result = await showGeneralDialog<LoginPromptResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'auth.login_required_title'.tr,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const LoginRequiredDialog(),
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    return result ?? LoginPromptResult.dismissed;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.appColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: c.surfaceSoft,
            elevation: 0,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lock badge — a soft, brand-tinted disc keeps it premium in
                  // both themes without a hard-coded background.
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 34,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'auth.login_required_title'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'auth.login_required_desc'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Primary CTA
                  FilledButton(
                    onPressed: () {
                      // Close the prompt first, then route — so the login
                      // screen animates in over the shell, not the dialog.
                      Navigator.of(context).pop(LoginPromptResult.login);
                      Navigator.of(context).pushNamed(Static.login);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text('auth.login_now'.tr),
                  ),
                  const SizedBox(height: 8),
                  // Secondary action
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(LoginPromptResult.dismissed),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: c.textSecondary,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text('auth.later'.tr),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
