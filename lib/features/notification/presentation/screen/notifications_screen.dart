import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_inbox_view.dart';

/// The full-screen inbox — the destination `app://notifications` resolves to.
///
/// ## Why a screen as well as the sheet
///
/// §11 makes `app://notifications` the **fallback for every unroutable deep
/// link**: an event that points at no single record, and any URI naming a screen
/// this build does not have yet. That fallback has to land somewhere with a back
/// button and a real route, not on a modal sheet raised over whatever the rep
/// happened to be doing — a cold start from a notification tap has nothing
/// underneath to raise a sheet over.
///
/// The body is [NotificationInboxView], the same widget the sheet uses, so the
/// swipe rules, the empty states and the action buttons cannot drift between the
/// two.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onOpenNotification});

  /// Routes a tapped notification on its `deep_link`.
  ///
  /// Supplied by the route builder rather than resolved here: this screen owns
  /// no navigator stack beyond itself, and §11's mapping lives in
  /// [NotificationDeepLink] so exactly one place knows it.
  final void Function(NotificationMessage notification)? onOpenNotification;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  late final NotificationInboxCubit _inbox;
  late final PushPermissionCubit _permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inbox = GetIt.instance<NotificationInboxCubit>()..start();
    _permission = GetIt.instance<PushPermissionCubit>()
      ..evaluate(hasSeenFirstRoute: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Factory registrations: these instances are this screen's, and nothing else
    // will close them. Skipping this leaks a Drift stream subscription per open.
    _inbox.close();
    _permission.close();
    super.dispose();
  }

  /// §6.1 and §16: catch up on every foreground.
  ///
  /// `NotificationCoordinator.onAppResumed` covers the app as a whole, but this
  /// screen refreshes on its own account too — a rep who backgrounds the app on
  /// the inbox and returns to it is the single most likely person to be waiting
  /// for something new, and the one who would most obviously notice a stale
  /// list.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _inbox.refresh();
    _permission.evaluate(hasSeenFirstRoute: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _inbox),
        BlocProvider.value(value: _permission),
      ],
      child: LocalizedBuilder(
        builder: (context) => Scaffold(
          backgroundColor: colors.canvas,
          appBar: AppBar(
            title: Text(
              'notifications.title'.tr,
              style: TextStyle(
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'notifications.settings.title'.tr,
                icon: Icon(Icons.tune_rounded, size: context.rr(20)),
                onPressed: () => Navigator.of(context).pushNamed(
                  NotificationDeepLink.notificationSettingsRoute,
                ),
              ),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      context.read<NotificationInboxCubit>().markAllRead(),
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
          ),
          // Caps the readable width on a tablet or a browser window rather than
          // stretching a list of short rows across 1440px.
          body: ResponsiveContentFrame(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                context.rh(8),
                context.pagePadding,
                context.rh(8),
              ),
              child: NotificationInboxView(
                onOpenNotification: widget.onOpenNotification,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
