/// The notification bell in the shell app bar: a medallion with an unread
/// count bound to the app-wide badge cubit. Restyle the bell or the badge here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_badge_cubit.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_sheet.dart';
import 'package:steelforce/features/shell/presentation/widgets/app_bar/app_bar_medallion_button.dart';

class AppBarNotificationBell extends StatelessWidget {
  const AppBarNotificationBell({
    super.key,
    this.isInverseColor = false,
    this.onTapOverride,
  });

  final bool isInverseColor;
  final VoidCallback? onTapOverride;

  /// The unread badge's red gradient (light → deep).
  static const Color _badgeRedLight = Color(0xFFEF4444);
  static const Color _badgeRedDeep = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    if (onTapOverride != null) {
      return _buildBellIcon(context, 0);
    }

    // Bound to the app-wide badge cubit rather than a `FutureBuilder`.
    //
    // The previous version re-ran a fetch on every app-bar rebuild — which is
    // every tab change — and showed a dot that was already stale by the time it
    // painted. This reads the local mirror, so it moves the instant a
    // notification arrives, the instant one is read, and correctly while
    // offline.
    //
    // The dot shows **unread** (§5.4): the bell answers "is there something to
    // look at". The app-icon badge is a different number — outstanding actions —
    // and is set by the backend in `aps.badge`.
    return BlocSelector<NotificationBadgeCubit, NotificationCounts, int>(
      bloc: sl<NotificationBadgeCubit>(),
      selector: (counts) => counts.unread,
      builder: (context, unread) => _buildBellIcon(context, unread),
    );
  }

  Widget _buildBellIcon(BuildContext context, int unread) {
    final scheme = Theme.of(context).colorScheme;

    // Icon-only control: the label gives a screen reader something to say.
    return Semantics(
      button: true,
      label: unread > 0
          ? '${'notifications.title'.tr}, $unread'
          : 'notifications.title'.tr,
      child: AppBarMedallionButton(
        isHome: isInverseColor,
        onTap: onTapOverride ??
            () => showNotificationsSheet(
                  context: context,
                  // Routing a tapped row is the coordinator's job: the backend
                  // builds every `deep_link` (§11) and exactly one place resolves
                  // them. The sheet pops first so the destination is not raised
                  // underneath it.
                  onOpenNotification: (notification) {
                    Navigator.of(context).pop();
                    sl<NotificationCoordinator>()
                        .openLink(notification.deepLink);
                  },
                ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: isInverseColor ? Colors.white : scheme.onSurface,
              size: context.rr(20),
            ),
            // Hidden at zero; capped so a long backlog stays one badge wide.
            if (unread > 0)
              Positioned(
                right: -context.rr(8),
                top: -context.rr(6),
                child: Container(
                  constraints: BoxConstraints(minWidth: context.rr(16)),
                  height: context.rr(16),
                  padding: EdgeInsets.symmetric(horizontal: context.rr(4)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_badgeRedLight, _badgeRedDeep],
                    ),
                    borderRadius: BorderRadius.circular(context.rr(8)),
                    border: Border.all(
                      color: isInverseColor ? Colors.black38 : Colors.white,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.rsp(9.5),
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
