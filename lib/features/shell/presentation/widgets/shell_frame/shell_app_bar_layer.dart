import 'package:flutter/material.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/network/api/server_url.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/about/presentation/screens/about_hub_screen.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/shell/presentation/widgets/app_bar/main_app_bar.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_actions.dart';
import 'package:steelforce/features/shell/presentation/widgets/shell_frame/shell_tabs.dart';

/// The app bar floating over every tab: logo, the tab's title, notifications
/// and the rep's avatar.
///
/// Rebuilt on session changes, so a picture saved on the profile screen
/// appears here without a restart. Hidden over the guest Home landing, which
/// is the whole screen.
class ShellAppBarLayer extends StatelessWidget {
  const ShellAppBarLayer({super.key, required this.index});

  /// The tab showing, as a [ShellTab] index.
  final int index;

  static String? _initialsOf(String? fullName) {
    final parts = (fullName ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return null;
    final last = parts.length > 1 ? parts.last[0] : '';
    return (parts.first[0] + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    return StreamBuilder<Object?>(
      stream: session.changes,
      builder: (context, _) {
        if (index == ShellTab.home && !session.isAuthenticated) {
          return const SizedBox.shrink();
        }
        final user = session.currentUser;
        return MainAppBar(
          onLogoTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AboutHubScreen()),
          ),
          title: shellNavTabs()[index].label,
          currentTabIndex: index,
          onBackToHomeTap: () => sl<ShellTabController>().goTo(ShellTab.home),
          onAvatarTap: () => openShellProfile(context),
          onNotificationTap: session.isAuthenticated
              ? null
              : () => openShellNotifications(context),
          avatarUrl: resolveServerUrl(user?.avatarUrl, AppConfig.apiBaseUrl),
          avatarInitials: _initialsOf(user?.fullName),
        );
      },
    );
  }
}
