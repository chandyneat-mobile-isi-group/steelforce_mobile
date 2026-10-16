import 'dart:async';

import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/notifications/local/local_notification_presenter.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/authentication/domain/notification_lifecycle.dart';
import 'package:steelforce/features/notification/domain/usecases/inbox_usecases.dart';
import 'package:steelforce/features/notification/domain/usecases/preferences_usecases.dart';
import 'package:steelforce/features/notification/domain/usecases/push_device_usecases.dart';

/// A push that arrived while the app was open, for the in-app card §10 requires
/// in place of an OS banner.
class ForegroundNotification {
  const ForegroundNotification({
    required this.title,
    required this.body,
    this.deepLink,
    this.categoryCode,
  });

  final String title;
  final String body;
  final String? deepLink;
  final String? categoryCode;
}

/// Wires push, connectivity and the app lifecycle to the notification inbox.
///
/// ## What this class is for
///
/// `docs/feature/notification/README.md` §16 is a checklist of things that are
/// each individually easy to forget and individually invisible when missed:
/// channels created before the first push, `getInitialMessage()` checked at
/// startup, `onTokenRefresh` wired to registration, catch-up on start *and* on
/// foreground, the queue drained on reconnect. Every one of them fails silently —
/// the app looks healthy and a rep quietly stops receiving work.
///
/// So they live together, in one place, with one entry point. A reviewer can read
/// [start] against §16 line by line.
///
/// ## What it deliberately does not do
///
/// **It never navigates.** Deep links are resolved and published on
/// [destinations]; a widget that owns a `Navigator` listens and moves. A
/// non-widget class reaching for a global navigator key is the pattern
/// `docs/skills/ai-engineering-playbook.md` §12 lists as an anti-pattern, and it is how
/// the app previously ended up with duplicate redirects and guests being yanked
/// between screens.
///
/// **It holds no state a screen needs.** Counts and lists come from the
/// repository's streams, which are fed by the local mirror, so a screen built
/// while this class was still starting up is not missing anything.
class NotificationCoordinator implements NotificationLifecycle {
  NotificationCoordinator({
    required PushMessagingService messaging,
    required LocalNotificationPresenter presenter,
    required ConnectivityService connectivity,
    required SessionManager session,
    required PendingNotificationLink pendingLink,
    required SyncNotifications syncNotifications,
    required RefreshNotificationCounts refreshCounts,
    required DrainNotificationActions drainActions,
    required IngestPushNotification ingestPush,
    required ClearNotifications clearNotifications,
    required RegisterPushDevice registerDevice,
    required DeregisterPushDevice deregisterDevice,
    required ClearNotificationPreferences clearPreferences,
    required AppLogger logger,
  })  : _messaging = messaging,
        _presenter = presenter,
        _connectivity = connectivity,
        _session = session,
        _pendingLink = pendingLink,
        _sync = syncNotifications,
        _refreshCounts = refreshCounts,
        _drain = drainActions,
        _ingest = ingestPush,
        _clearInbox = clearNotifications,
        _register = registerDevice,
        _deregister = deregisterDevice,
        _clearPreferences = clearPreferences,
        _logger = logger;

  final PushMessagingService _messaging;
  final LocalNotificationPresenter _presenter;
  final ConnectivityService _connectivity;
  final SessionManager _session;
  final PendingNotificationLink _pendingLink;
  final SyncNotifications _sync;
  final RefreshNotificationCounts _refreshCounts;
  final DrainNotificationActions _drain;
  final IngestPushNotification _ingest;
  final ClearNotifications _clearInbox;
  final RegisterPushDevice _register;
  final DeregisterPushDevice _deregister;
  final ClearNotificationPreferences _clearPreferences;
  final AppLogger _logger;

  final _destinations = StreamController<NotificationDestination>.broadcast();
  final _foreground = StreamController<ForegroundNotification>.broadcast();
  final _resolvedElsewhere = StreamController<List<String>>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _started = false;

  /// Deep links to open, resolved from a tapped notification.
  ///
  /// `NotificationHost` subscribes to this. A destination is published only when
  /// the app can actually act on it — otherwise it is parked in
  /// [PendingNotificationLink] and replayed after login, per §10's "preserve the
  /// deep link across login".
  Stream<NotificationDestination> get destinations => _destinations.stream;

  /// Pushes that arrived with the app open, for the in-app card (§10).
  Stream<ForegroundNotification> get foregroundNotifications =>
      _foreground.stream;

  /// Notification ids that came back `409 Notification.AlreadyResolved` when the
  /// queue drained — somebody else decided while the rep was offline.
  ///
  /// §8.5 and §13.6 require this be *told* to the rep, never silently discarded:
  /// they acknowledged something and need to know why it no longer shows as
  /// theirs.
  Stream<List<String>> get resolvedElsewhere => _resolvedElsewhere.stream;

  /// The §16 startup checklist, in order.
  ///
  /// Safe to await from the boot sequence: nothing here blocks on the network.
  /// The catch-up and the device registration are fired without awaiting, so a
  /// dead gateway cannot delay the first frame — the rule
  /// `AppBootstrapService` exists to enforce (ADR-002 §3).
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 1. Channels first, before any message can arrive. Android drops a push
    //    naming a channel that does not exist into a default the rep cannot see
    //    or control, so this cannot wait for a message to prompt it (§9.3).
    await _presenter.initialize(onTap: _onLocalNotificationTap);
    await _presenter.registerChannels((key) => key.tr);

    // 2. Transport. Never throws — a misconfigured Firebase project must cost
    //    push, not the app.
    await _messaging.initialize();
    await _messaging.suppressForegroundAlerts();

    // 3. The terminated-state tap. **Must be checked here**: read once and only
    //    once, and if it is not read the rep's tap is swallowed entirely — they
    //    tap, the app opens on the home screen, and the thing they were told
    //    about is nowhere (§10, §16).
    final initial = await _messaging.initialMessage();
    if (initial != null) await _handleOpened(initial);

    _subscriptions.addAll([
      _messaging.onForegroundMessage.listen(_handleForeground),
      _messaging.onMessageOpened.listen(_handleOpened),

      // 4. Token rotation → re-register. FCM rotates silently, and a rotated
      //    token that is never re-registered is the failure with no symptom
      //    (§4.1).
      _messaging.tokenRefreshes.listen((_) => _registerQuietly()),

      // 5. Reconnect → drain the queue, then catch up. Both, in that order:
      //    draining first pushes the rep's own acknowledgements before pulling
      //    the server's view, so the two converge instead of fighting.
      _connectivity.changes.listen((status) {
        if (status == ConnectivityStatus.online) unawaited(_onReconnect());
      }),

      // 6. A session appearing or disappearing. Registration and the inbox are
      //    both rep-scoped, so this is what makes sign-in and sign-out do the
      //    right thing without every call site remembering to.
      _session.stateChanges.listen(_onSessionState),
    ]);

    // 7. Catch-up and registration on launch — §4.1 requires registration on
    //    *every* launch, not only the first. Fire-and-forget so boot never waits
    //    on the network.
    unawaited(_catchUpQuietly());
    unawaited(_registerQuietly());

    _logger.info('notifications.coordinator_started', fields: {
      'pushSupported': _messaging.isSupported,
    });
  }

  /// Call when the app returns to the foreground.
  ///
  /// §6.1 and §7: catch up and reconcile the counts on every foreground. This is
  /// the path that makes a dropped push cost nothing — and the only path for a
  /// P4, which is never pushed at all.
  Future<void> onAppResumed() async {
    if (!_started) return;
    // Re-probe before deciding: `ConnectivityService` may hold a state from
    // before the phone was pocketed, and a stale "offline" would skip a sync
    // that would have worked.
    await _connectivity.refresh();
    await _drainAndReport();
    await _catchUpQuietly();
  }

  /// Call after a successful sign-in.
  ///
  /// §16: register the device after login, and pull the new rep's inbox from
  /// scratch — the cursor and rows belong to whoever was signed in before.
  @override
  Future<void> onSignedIn() async {
    await _registerQuietly();
    await _catchUpQuietly(full: true);
  }

  /// Call **before** the access token is discarded on sign-out.
  ///
  /// Order is the whole point (§4.4): deregistration needs the bearer token, so
  /// it goes first. Local state is cleared afterwards — an inbox is rep-scoped
  /// PII and a queued acknowledgement must never replay under the next rep's
  /// token.
  @override
  Future<void> onSigningOut() async {
    await _deregister(const NoParams());
    await _presenter.cancelAll();
    _pendingLink.clear();
    await _clearInbox();
    await _clearPreferences();
    _logger.info('notifications.signed_out_cleanup');
  }

  /// Publishes [link] as a destination if it can be opened now, or parks it.
  ///
  /// Public so the login screen can replay a parked link once a session exists.
  void openLink(String? link) {
    final destination = NotificationDeepLink.resolve(link);
    if (destination == null) return;

    // §10, terminated state: *"If the session expired, preserve the deep link
    // across login."* Dropping it here means the rep signs in and lands on the
    // home screen with no trace of what they tapped.
    if (!_session.isAuthenticated) {
      _pendingLink.set(link);
      _logger.info('notifications.deep_link_parked');
      return;
    }

    if (!_destinations.isClosed) _destinations.add(destination);
  }

  /// Replays a parked deep link, if there is one. Called once a session exists.
  void replayPendingLink() {
    final link = _pendingLink.take();
    if (link == null) return;
    _logger.info('notifications.deep_link_replayed');
    openLink(link);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _destinations.close();
    await _foreground.close();
    await _resolvedElsewhere.close();
  }

  // ── Handlers ────────────────────────────────────────────────────────

  /// A push while the app is open.
  ///
  /// The OS banner is already suppressed, so §10's in-app card is the alert.
  /// [ForegroundNotification] is published for whatever surface is visible; the
  /// local presenter is the fallback for a push whose screen is not on top.
  void _handleForeground(PushMessage push) {
    unawaited(_ingestAndRefresh(push));

    // A data-only push is a background sync trigger with no user-visible alert
    // (§10). Ingesting it is the entire response.
    if (push.isSilent) return;

    final notification = ForegroundNotification(
      title: push.title ?? '',
      body: push.body ?? '',
      deepLink: push.deepLink,
      categoryCode: push.categoryCode,
    );
    if (!_foreground.isClosed) _foreground.add(notification);
  }

  /// The rep tapped a notification.
  Future<void> _handleOpened(PushMessage push) async {
    // Ingested before routing, so a screen opened by the link finds the row
    // already present rather than racing the catch-up for it.
    await _ingestAndRefresh(push);

    // §11: an event pointing at no single record falls back to
    // `app://notifications` server-side. A push with no link at all still opens
    // the inbox, which is the one destination guaranteed to explain itself.
    openLink(push.deepLink ?? NotificationDeepLink.inboxUri);
  }

  /// A tap on an alert this app drew itself. The payload is the deep link.
  void _onLocalNotificationTap(String? payload) => openLink(payload);

  Future<void> _ingestAndRefresh(PushMessage push) async {
    await _ingest(IngestPushNotificationParams(
      data: push.data,
      title: push.title,
      body: push.body,
    ));
    // §7: reconcile against the server rather than trusting the push's own
    // `notification_count`, which is a snapshot from when it was raised.
    await _refreshCounts(const NoParams());
  }

  void _onSessionState(AuthenticationState state) {
    switch (state) {
      case AuthenticationState.authenticated:
        // Covers a session restored at boot as well as a fresh sign-in, so a rep
        // reopening the app is registered without the splash screen having to
        // remember to ask.
        unawaited(onSignedIn());
        replayPendingLink();
      case AuthenticationState.sessionExpired:
        // Not a sign-out. The rep is about to be asked to sign in again and the
        // same session will very likely come back, so the inbox is left alone —
        // clearing it would throw away rows and a cursor that are still valid,
        // and re-pulling them costs the rep a wait for no gain.
        _logger.info('notifications.session_expired_inbox_retained');
      case AuthenticationState.guest:
      case AuthenticationState.initializing:
      case AuthenticationState.authenticating:
      case AuthenticationState.refreshingToken:
        break;
    }
  }

  Future<void> _onReconnect() async {
    await _drainAndReport();
    await _catchUpQuietly();
  }

  Future<void> _drainAndReport() async {
    final result = await _drain(const NoParams());
    result.when(
      success: (ids) {
        if (ids.isEmpty) return;
        if (!_resolvedElsewhere.isClosed) _resolvedElsewhere.add(ids);

        // Also surfaced as an OS alert, because the rep may well not be looking
        // at the app when the reconnect happens — which is the normal case, and
        // the reason §8.5 spells this out rather than leaving it to a snackbar.
        unawaited(_presenter.show(
          title: 'notifications.resolved_elsewhere.title'.tr,
          body: 'notifications.resolved_elsewhere.body'.tr,
          categoryCode: 'SYSTEM',
          payload: NotificationDeepLink.inboxUri,
        ));
      },
      failure: (_) {
        // Already logged inside the repository. Nothing to do: the queue
        // survives and retries on the next reconnect.
      },
    );
  }

  Future<void> _catchUpQuietly({bool full = false}) async {
    final result = await _sync(SyncNotificationsParams(full: full));
    result.when(
      success: (_) {},
      // A failed catch-up is not a user-facing error. The rep is looking at the
      // inbox they already had, which is still valid — offline is a normal
      // state, not an error state (ADR-002 §4). The pull-to-refresh path reports
      // failures, because there a human explicitly asked.
      failure: (_) {},
    );
  }

  Future<void> _registerQuietly() async {
    final result = await _register(const NoParams());
    result.when(
      success: (_) {},
      // Retried on the next launch, on the next token rotation, and on the next
      // permission change — §4.1's four triggers are precisely so that no single
      // failure is permanent.
      failure: (_) {},
    );
  }
}
