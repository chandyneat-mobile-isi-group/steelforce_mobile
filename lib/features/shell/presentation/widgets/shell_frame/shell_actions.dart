import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/auth/auth_guard.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_sheet.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/screens/profile_screen.dart';

/// Opens the profile, asking a guest to sign in first.
Future<void> openShellProfile(BuildContext context) async {
  final allowed = await AuthGuard.requireAuthentication(context);
  if (!allowed || !context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => sl<ProfileCubit>(),
        child: LocalizedBuilder(builder: (_) => const ProfileScreen()),
      ),
    ),
  );
}

/// Opens the notifications sheet from the app bar bell (guests only; a
/// signed-in rep's bell is handled by the app bar itself).
void openShellNotifications(BuildContext context) {
  showNotificationsSheet(
    context: context,
    isGuest: !sl<SessionManager>().isAuthenticated,
    onLogin: () => openShellProfile(context),
    // A guest never reaches this callback — the sheet shows the sign-in
    // prompt instead of a list — but wiring it means the one entry point
    // behaves identically the moment a session exists, rather than silently
    // having non-tappable rows for a signed-in rep who arrived this way.
    onOpenNotification: (notification) {
      Navigator.of(context).pop();
      sl<NotificationCoordinator>().openLink(notification.deepLink);
    },
  );
}
