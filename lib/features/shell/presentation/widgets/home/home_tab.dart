import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_home_screen.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/authenticated_home_view.dart';

/// The Home tab: the guest landing or the signed-in home, cross-faded when
/// the session changes (sign-in or sign-out).
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onLogin});

  /// Opens sign-in from the guest landing.
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    return StreamBuilder<Object?>(
      stream: session.changes,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: session.isAuthenticated
              // Not const: the name is re-read on every session change, so
              // an edit on the profile screen shows here without a restart.
              ? AuthenticatedHomeView(
                  key: const ValueKey('authenticated_home_view'),
                  fullName: session.currentUser?.fullName ?? '',
                )
              : GuestHomeScreen(
                  key: const ValueKey('guest_home_view'),
                  onLogin: onLogin,
                ),
        );
      },
    );
  }
}
