import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/features/localization/domain/usecases/restore_saved_language.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_badge_cubit.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:steelforce/routes/app_routes.dart';

/// Starts the notification machinery and turns its two output streams into
/// things a user can see: a navigation, and an in-app card.
///
/// ## Why this lives under `MaterialApp` rather than in the boot sequence
///
/// Two of `NotificationCoordinator.start()`'s steps need what boot does not yet
/// have:
///
///  * **Translated Android channel names.** The language bundle is loaded
///    asynchronously by `LanguageCubit` when the widget tree builds, so `.tr`
///    returns raw keys during `AppBootstrapService`. Android caches a channel's
///    name at creation and **ignores every later rename** — a deliberate
///    protection for the user's own settings — so creating the ten channels
///    before the bundle lands would pin every rep's system settings to strings
///    like `notifications.channel.assignment.name`, permanently.
///  * **A Navigator.** A tapped notification has to go somewhere.
///
/// [_ensureLanguageLoaded] closes the first gap explicitly rather than hoping a
/// frame or two is enough.
///
/// ## Why it navigates through `navigatorKey`
///
/// This widget sits in `MaterialApp.builder`, which wraps the Navigator rather
/// than sitting beneath it, so `Navigator.of(context)` would not find one. The
/// app already keeps a `navigatorKey` for exactly this class of need.
///
/// This is not the global-listener anti-pattern `docs/skills/ai-engineering-playbook.md`
/// §12 warns about: that one is a session listener redirecting users who did not
/// ask to move. Here a rep tapped a notification. Navigation is the only correct
/// response, and doing it anywhere else would mean every screen re-implementing
/// the same routing table.
class NotificationHost extends StatefulWidget {
  const NotificationHost({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<NotificationHost>
    with WidgetsBindingObserver {
  final NotificationCoordinator _coordinator =
      GetIt.instance<NotificationCoordinator>();
  final NotificationBadgeCubit _badges =
      GetIt.instance<NotificationBadgeCubit>();

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _badges.start();

    _subscriptions.addAll([
      _coordinator.destinations.listen(_navigate),
      _coordinator.foregroundNotifications.listen(_showForegroundCard),
      _coordinator.resolvedElsewhere.listen(_showResolvedElsewhere),
    ]);

    unawaited(_startCoordinator());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    // The coordinator and the badge cubit are app-scoped singletons and are
    // deliberately not closed here: this widget is rebuilt on every language
    // change and on every sign-out restart (`app.dart` keys the whole
    // `MaterialApp` on both), and tearing push down each time would drop the
    // FCM subscription and the badge stream for the rest of the session.
    super.dispose();
  }

  /// §6.1, §7, §16: catch up and reconcile the badges on every foreground.
  ///
  /// This is the path that makes a dropped push cost nothing — and the only
  /// path at all for a P4, which is never pushed by design (§5.2).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_coordinator.onAppResumed());
    unawaited(_badges.reconcile());
  }

  Future<void> _startCoordinator() async {
    await _ensureLanguageLoaded();
    if (!mounted) return;
    await _coordinator.start();
  }

  /// Loads the persisted language bundle before the channels are created.
  ///
  /// Idempotent and cheap — `LanguageCubit` calls the same use case from its
  /// constructor, and re-applying a language rewrites nothing. Awaiting it here
  /// rather than racing that constructor is what guarantees the channel names
  /// are real words on the very first launch, which is the only launch that gets
  /// to decide them.
  Future<void> _ensureLanguageLoaded() async {
    try {
      await GetIt.instance<RestoreSavedLanguage>()();
    } catch (_) {
      // A failed bundle load already logs inside `LocalizationService`, and it
      // must not stop push from starting: English channel names are a cosmetic
      // problem, no push at all is not.
    }
  }

  /// Opens a resolved destination.
  ///
  /// Most of these live inside `MainShell`'s `IndexedStack`, so "go to My
  /// Visits" is a **tab selection**, not a push — pushing the tab's screen on
  /// top of the shell would strand the rep with no bottom navigation. The
  /// mapping from route name to tab index lives here, using the home feature's
  /// own `ShellTab` constants, so there is exactly one copy of it.
  void _navigate(NotificationDestination destination) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final tab = _shellTabFor(destination.route);
    if (tab != null) {
      GetIt.instance<ShellTabController>().goTo(tab);
      // Drop anything stacked over the shell — a settings screen, a detail
      // page — so the selected tab is actually visible rather than hidden
      // behind whatever the rep had open.
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    navigator.pushNamed(destination.route, arguments: destination.arguments);
  }

  int? _shellTabFor(String route) => switch (route) {
        Static.main => ShellTab.home,
        Static.depot => ShellTab.depots,
        Static.myVisits => ShellTab.myVisits,
        Static.order => ShellTab.orders,
        _ => null,
      };

  /// §10, foreground: the OS banner is suppressed, so this is the alert.
  ///
  /// A `SnackBar` with an action rather than a full-bleed overlay: the rep is
  /// already using the app and mid-task, and a notification that covers what
  /// they are doing is an interruption the tier system has already decided this
  /// message does not warrant.
  void _showForegroundCard(ForegroundNotification notification) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notification.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (notification.body.isNotEmpty)
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        action: notification.deepLink == null
            ? null
            : SnackBarAction(
                label: 'common.view'.tr,
                onPressed: () => _coordinator.openLink(notification.deepLink),
              ),
      ),
    );
  }

  /// §8.5 and §13.6: when a queued action drains into a
  /// `409 Notification.AlreadyResolved`, the rep is *told*, never silently
  /// ignored.
  ///
  /// The coordinator also raises an OS notification for this, because a
  /// reconnect usually happens while the app is not being looked at. This is the
  /// in-app half, for when it is.
  void _showResolvedElsewhere(List<String> notificationIds) {
    if (notificationIds.isEmpty) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('notifications.resolved_elsewhere.body'.tr),
        action: SnackBarAction(
          label: 'common.view'.tr,
          onPressed: () => _coordinator.openLink(NotificationDeepLink.inboxUri),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
