import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';

/// Handles a push that arrives while the app is backgrounded or terminated.
///
/// ## Why this does so little
///
/// It runs in a **separate background isolate** with its own memory, no widget
/// tree, and none of this app's DI graph. It deliberately does not open the
/// encrypted database or call the API, for two concrete reasons:
///
///  1. `AppDatabase` is keyed by a composite passphrase derived from a
///     hardware-sealed key read through `flutter_secure_storage` — a platform
///     channel. A background isolate has no reliable channel to the platform
///     plugin registrant, and opening SQLCipher twice from two isolates against
///     one file is a corruption risk, not a performance question.
///  2. It is not needed. The inbox is the system of record and the catch-up call
///     on next foreground pulls everything since the cursor
///     (`docs/feature/notification/README.md` §6.1). A background write would
///     duplicate work the foreground path already guarantees, while adding the
///     one failure mode the design has no answer for: a half-written encrypted
///     row nobody is around to see.
///
/// So it exists to satisfy `firebase_messaging`'s requirement that a background
/// handler be registered — without one, the plugin logs a warning on every
/// background delivery and data-only messages are dropped before Dart sees them
/// at all — and nothing more. The OS still renders any push carrying a
/// `notification` block, which is the whole of the user-visible behaviour here.
///
/// Must be a top-level function annotated `@pragma('vm:entry-point')`: tree
/// shaking removes it otherwise, and the failure is a release-only crash on the
/// first background push.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // A fresh isolate has no initialised Firebase app.
  await Firebase.initializeApp();
}

/// `firebase_messaging`-backed transport for Android and iOS.
///
/// Every public method is failure-tolerant on purpose. A Firebase project with
/// a missing `google-services.json`, a revoked APNs key, or a Play-Services-less
/// handset must degrade to "no push" and leave the inbox working — §1's whole
/// premise is that a dropped push costs nothing, and an exception thrown out of
/// initialisation would cost the entire app.
class FirebasePushMessagingService implements PushMessagingService {
  FirebasePushMessagingService(this._logger);

  final AppLogger _logger;

  FirebaseMessaging? _messaging;
  bool _initialized = false;

  /// True once initialisation has failed, so the app stops retrying a
  /// misconfiguration that cannot fix itself between two calls in one session.
  bool _unavailable = false;

  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  final _tokens = StreamController<String>.broadcast();

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  bool get isSupported => !_unavailable;

  @override
  Future<void> initialize() async {
    // §4.1 has registration running on every launch and a language change
    // rebuilds the whole tree, so re-entry is normal rather than a bug to
    // assert against.
    if (_initialized || _unavailable) return;

    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      // Registered before any listener so a background delivery during startup
      // is not dropped.
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

      _subscriptions.addAll([
        FirebaseMessaging.onMessage.listen(_emitForeground),
        FirebaseMessaging.onMessageOpenedApp.listen(_emitOpened),
        messaging.onTokenRefresh.listen((token) {
          // The token itself is never logged: it is a per-installation
          // credential for sending to this handset, and `docs/skills/security.md` §10
          // keeps credentials out of logs. That it rotated is the useful fact.
          _logger.info('push.token_rotated');
          if (!_tokens.isClosed) _tokens.add(token);
        }),
      ]);

      _initialized = true;
      _logger.info('push.initialized');
    } catch (error, stackTrace) {
      // Loud, but not fatal. This is the single most likely thing to be
      // misconfigured in a fresh environment, and the symptom otherwise — the
      // inbox works, nothing is ever pushed — gives no hint where to look.
      _unavailable = true;
      _logger.error('push.initialize_failed',
          error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<String?> token() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      // On iOS this returns null until APNs has handed back a device token,
      // which happens only after the permission is granted. Null is therefore a
      // normal answer before the explainer has been accepted, not an error.
      return await messaging.getToken();
    } on FirebaseException catch (error) {
      // The **code**, not the runtime type. `FirebaseException` on its own says
      // nothing — every failure here reports it — and an error code is
      // explicitly allowed in logs by `docs/skills/security.md` §10. Logging the
      // type instead sent a real debugging session off to check iOS Settings for
      // a permission that was already granted.
      _logger.warning('push.token_unavailable', fields: {
        'code': error.code,
        'reason': _tokenFailureReason(error.code),
      });
      return null;
    } catch (error) {
      _logger.warning('push.token_unavailable',
          fields: {'error': error.runtimeType.toString()});
      return null;
    }
  }

  /// Plain-language cause for a `getToken()` failure code.
  ///
  /// `apns-token-not-set` is by far the most common and the most misleading:
  /// FCM cannot mint a registration token until APNs has issued a device token
  /// first, and **the iOS Simulator never issues one**. The notification
  /// permission is unrelated — it can be fully granted and this still fails —
  /// so naming the real cause here saves the next person from auditing
  /// Settings, entitlements and the provisioning profile in turn.
  String _tokenFailureReason(String code) => switch (code) {
        'apns-token-not-set' =>
          'No APNs device token. Expected on the iOS Simulator, which never '
              'issues one — use a physical device. On a real device this also '
              'appears when getToken() runs before APNs has replied.',
        'unregistered' ||
        'token-unsubscribed' =>
          'The registration was revoked. It is re-minted on the next launch.',
        _ => 'See the Firebase Messaging error code.',
      };

  @override
  Stream<String> get tokenRefreshes => _tokens.stream;

  @override
  Future<PushAuthorization> authorization() async {
    final messaging = _messaging;
    if (messaging == null) return PushAuthorization.unsupported;
    try {
      final settings = await messaging.getNotificationSettings();
      return _mapAuthorization(settings.authorizationStatus);
    } catch (error) {
      _logger.warning('push.authorization_unavailable',
          fields: {'error': error.runtimeType.toString()});
      return PushAuthorization.unsupported;
    }
  }

  @override
  Future<PushAuthorization> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return PushAuthorization.unsupported;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        // Not requested. A provisional grant on iOS delivers quietly to
        // Notification Centre with no prompt — which is the right default for
        // an app that wants to earn attention, and the wrong one here: §14 has
        // already spent an explainer card establishing why a route assignment
        // needs to interrupt, so asking for the real thing is what the rep just
        // agreed to.
        provisional: false,
      );
      final status = _mapAuthorization(settings.authorizationStatus);
      _logger.info('push.permission_result', fields: {'status': status.name});
      return status;
    } catch (error, stackTrace) {
      _logger.error('push.permission_request_failed',
          error: error, stackTrace: stackTrace);
      return PushAuthorization.denied;
    }
  }

  @override
  Stream<PushMessage> get onForegroundMessage => _foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      final message = await messaging.getInitialMessage();
      if (message == null) return null;
      _logger.info('push.cold_start_from_notification');
      return _toPushMessage(message);
    } catch (error) {
      _logger.warning('push.initial_message_failed',
          fields: {'error': error.runtimeType.toString()});
      return null;
    }
  }

  @override
  Future<void> suppressForegroundAlerts() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        // The in-app card replaces it (§10).
        alert: false,
        // Kept: the icon badge the backend sends in `aps.badge` is the
        // authoritative outstanding-action count and should still land.
        badge: true,
        sound: false,
      );
    } catch (error) {
      _logger.warning('push.foreground_options_failed',
          fields: {'error': error.runtimeType.toString()});
    }
  }

  @override
  Future<void> deleteToken() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      await messaging.deleteToken();
      _logger.info('push.token_deleted');
    } catch (error) {
      // Sign-out must not fail because a token could not be dropped. The
      // server-side `DELETE /mobile/devices/{deviceId}` is what actually stops
      // the sends; this is the second line of defence, not the first.
      _logger.warning('push.token_delete_failed',
          fields: {'error': error.runtimeType.toString()});
    }
  }

  /// Releases the plugin subscriptions and closes the streams.
  ///
  /// Not part of the interface — nothing in the app tears push down mid-session,
  /// and sign-out deletes the token rather than the transport. Present so a test
  /// can dispose one without leaking a listener into the next test.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _foreground.close();
    await _opened.close();
    await _tokens.close();
  }

  void _emitForeground(RemoteMessage message) {
    final push = _toPushMessage(message);
    _logger.info('push.foreground', fields: {
      'event': push.eventCode,
      'category': push.categoryCode,
      'silent': push.isSilent,
    });
    if (!_foreground.isClosed) _foreground.add(push);
  }

  void _emitOpened(RemoteMessage message) {
    final push = _toPushMessage(message);
    _logger.info('push.opened', fields: {'event': push.eventCode});
    if (!_opened.isClosed) _opened.add(push);
  }

  /// `RemoteMessage` → [PushMessage].
  ///
  /// `data` arrives as `Map<String, dynamic>` even though FCM can only carry
  /// strings, so the values are stringified rather than cast: a cast would throw
  /// on the first platform that hands back a decoded number, and losing a push
  /// to a type error is not a trade worth making.
  PushMessage _toPushMessage(RemoteMessage message) => PushMessage(
        data: {
          for (final entry in message.data.entries)
            entry.key: entry.value?.toString() ?? '',
        },
        title: message.notification?.title,
        body: message.notification?.body,
      );

  PushAuthorization _mapAuthorization(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized => PushAuthorization.authorized,
        AuthorizationStatus.provisional => PushAuthorization.provisional,
        AuthorizationStatus.denied => PushAuthorization.denied,
        AuthorizationStatus.deniedPermanently =>
          PushAuthorization.deniedPermanently,
        AuthorizationStatus.notDetermined => PushAuthorization.notDetermined,
      };
}

/// Builds the native transport. Selected by
/// `push_messaging_service_factory.dart` on Android and iOS.
PushMessagingService createPushMessagingService(AppLogger logger) =>
    FirebasePushMessagingService(logger);
