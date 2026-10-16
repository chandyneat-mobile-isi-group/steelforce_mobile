import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_inbox_view.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/coming_soon_view.dart';

/// Opens the notifications sheet.
///
/// Goes through [showAppBottomSheet] rather than `showModalBottomSheet`
/// directly: that shared helper owns the sheet chrome every other sheet in the
/// app uses (surface colour, 20pt corner radius, drag handle, keyboard inset,
/// safe area, tablet width). This sheet previously re-declared its own and had
/// drifted to a 22pt radius with no handle.
///
/// [onOpenNotification] receives a tapped notification so the caller — which
/// owns a `Navigator` and knows it must pop the sheet first — can route on its
/// `deep_link`. Null leaves rows tappable for the read gesture only, which is
/// the correct behaviour for a surface with nowhere to send them.
Future<void> showNotificationsSheet({
  required BuildContext context,
  bool isGuest = false,
  VoidCallback? onLogin,
  void Function(NotificationMessage notification)? onOpenNotification,
  VoidCallback? onOpenSettings,
}) {
  if (!FeatureFlags.notifications) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) => LocalizedBuilder(
        builder: (_) => ComingSoonView(
          icon: Icons.notifications_active_rounded,
          title: 'notifications.coming_soon.title'.tr,
          subtitle: 'notifications.coming_soon.subtitle'.tr,
          actionLabel: 'common.close'.tr,
          actionIcon: Icons.close_rounded,
          onAction: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }
  return showAppBottomSheet<void>(
    context: context,
    heightFactor: 0.75,
    builder: (_) => _NotificationsSheet(
      isGuest: isGuest,
      onLogin: onLogin,
      onOpenNotification: onOpenNotification,
      onOpenSettings: onOpenSettings,
    ),
  );
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.isGuest,
    this.onLogin,
    this.onOpenNotification,
    this.onOpenSettings,
  });

  final bool isGuest;
  final VoidCallback? onLogin;
  final void Function(NotificationMessage notification)? onOpenNotification;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return LocalizedBuilder(
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          context.rh(16),
          context.pagePadding,
          context.rh(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(showMarkAllRead: !isGuest),
            SizedBox(height: context.rh(12)),
            Expanded(
              child: isGuest
                  ? _GuestMessage(onLogin: onLogin)
                  : _SheetInbox(
                      onOpenNotification: onOpenNotification,
                      onOpenSettings: onOpenSettings,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provides the cubits and starts them.
///
/// Built here rather than by the caller so every entry point to the sheet — the
/// app bar bell, the guest path in the shell, a future one — gets an inbox that
/// is subscribed and syncing without having to remember two `start()` calls.
class _SheetInbox extends StatefulWidget {
  const _SheetInbox({this.onOpenNotification, this.onOpenSettings});

  final void Function(NotificationMessage notification)? onOpenNotification;
  final VoidCallback? onOpenSettings;

  @override
  State<_SheetInbox> createState() => _SheetInboxState();
}

class _SheetInboxState extends State<_SheetInbox> {
  late final NotificationInboxCubit _inbox;
  late final PushPermissionCubit _permission;

  @override
  void initState() {
    super.initState();
    _inbox = GetIt.instance<NotificationInboxCubit>()..start();
    _permission = GetIt.instance<PushPermissionCubit>();

    // §14's gate. The rep has opened their notifications, which is a stronger
    // signal of intent than "has seen a route" and lands the explainer at a
    // moment where "get notified the moment a route needs you" is self-evidently
    // about what they are looking at.
    _permission.evaluate(hasSeenFirstRoute: true);
  }

  @override
  void dispose() {
    // Both are `registerFactory`, so these instances belong to this sheet and
    // nothing else will close them. Leaving them open leaks a Drift stream
    // subscription per sheet open.
    _inbox.close();
    _permission.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _inbox),
        BlocProvider.value(value: _permission),
      ],
      child: NotificationInboxView(
        onOpenNotification: widget.onOpenNotification,
        onOpenSettings: widget.onOpenSettings,
        // Tabs are shown here too: "Action needed" is the one surface a rep must
        // be able to reach, and hiding it on a phone would hide the whole point
        // of `requires_ack` (§5.4).
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showMarkAllRead});

  final bool showMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: Text(
            'notifications.title'.tr,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(17),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (showMarkAllRead)
          // Scoped to the active category filter by the cubit, per §8.2: the
          // button clears what the rep can see, not what they cannot.
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  context.read<NotificationInboxCubit>().markAllRead(),
              style: TextButton.styleFrom(
                minimumSize: Size(0, context.rh(36)),
                padding: EdgeInsets.symmetric(horizontal: context.rw(10)),
              ),
              child: Text(
                'notifications.mark_all_read'.tr,
                style: TextStyle(
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuestMessage extends StatelessWidget {
  const _GuestMessage({this.onLogin});

  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Scrollable, not a bare centred Column: the sheet is capped at a fraction
    // of the viewport, and on a short one — landscape, or a small phone at the
    // tablet type scale — this block is taller than the space it gets and
    // overflowed the flex (verified at 800x600: 177px over). Centring still
    // applies whenever the content does fit.
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rw(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.waving_hand_rounded,
                size: context.rr(56),
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: context.rh(16)),
              Text(
                // `notifications.*` (plural), not `notification.*`: the singular
                // namespace existed only in en.json, so every string in this
                // guest state rendered as a raw key in Khmer.
                'notifications.welcome_title'.tr,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: context.rh(8)),
              Text(
                'notifications.welcome_body'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(14),
                  height: 1.4,
                ),
              ),
              if (onLogin != null) ...[
                SizedBox(height: context.rh(20)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onLogin!.call();
                    },
                    icon: Icon(Icons.login_rounded, size: context.rr(18)),
                    label: Text(
                      'notifications.login'.tr,
                      style: TextStyle(
                        fontSize: context.rsp(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
