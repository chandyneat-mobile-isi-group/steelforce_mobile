import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/local/local_notification_presenter.dart';
import 'package:steelforce/core/notifications/notification_channels.dart';

/// `flutter_local_notifications`-backed presenter for Android and iOS.
class NativeLocalNotificationPresenter implements LocalNotificationPresenter {
  NativeLocalNotificationPresenter(this._logger,
      {FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final AppLogger _logger;

  /// Ids only have to be unique among *live* notifications, and Android caps
  /// them at a 32-bit int. A counter would collide across launches; a random
  /// value in a wide range effectively never does, and the consequence of a
  /// collision is one alert replacing another rather than anything lost.
  final Random _ids = Random();

  bool _initialized = false;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        // Named `settings:` since v19 — it was the first positional argument
        // before. The rename is the only change; the payload is identical.
        settings: const InitializationSettings(
          // The dedicated monochrome silhouette, not the launcher icon.
          //
          // The comment here used to claim `launcher_icon` was
          // "monochrome-safe". It is not: it is the full-colour app icon, and
          // Android fills a small icon's *alpha silhouette* with the accent
          // colour — so an opaque square renders as an opaque square. Locally
          // drawn alerts had the same featureless block as the FCM ones, from
          // the same mistake in two places.
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
            // All three false, deliberately. This plugin would otherwise show
            // the OS permission prompt during startup, and §14 spends iOS's
            // single prompt from the in-app explainer after the rep has seen
            // their first route. `PushMessagingService.requestPermission` owns
            // it; asking twice from two plugins is how an app ends up
            // permanently silent with nobody sure which call did it.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => onTap(response.payload),
      );
      _initialized = true;
    } catch (error, stackTrace) {
      // Never fatal: local alerts are a convenience layer over an inbox that
      // works without them.
      _logger.error('local_notifications.initialize_failed',
          error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> registerChannels(String Function(String key) translate) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Null on iOS, where notification categories are not a thing the app
    // declares up front. Not an error.
    if (android == null) return;

    var created = 0;
    for (final channel in NotificationChannels.all) {
      try {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            translate(channel.nameKey),
            description: translate(channel.descriptionKey),
            importance: _importance(channel.importance),
          ),
        );
        created++;
      } catch (error) {
        // One bad channel must not cost the other nine. A category with no
        // channel still delivers — it lands in `system` per the manifest
        // default — so this degrades rather than breaks.
        _logger.warning('local_notifications.channel_failed', fields: {
          'channel': channel.id,
          'error': error.runtimeType.toString(),
        });
      }
    }
    _logger.info('local_notifications.channels_ready', fields: {
      'created': created,
      'expected': NotificationChannels.all.length,
    });
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? categoryCode,
    String? payload,
    String? groupKey,
    bool silent = false,
  }) async {
    if (!_initialized) return;

    final channel = NotificationChannels.forCategory(categoryCode);
    final importance = _importance(channel.importance);

    try {
      await _plugin.show(
        // Named arguments since v19; `id`, `title`, `body` and the details were
        // positional before.
        id: _ids.nextInt(1 << 30),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            // Only used if the channel does not already exist; the registrar
            // has created it at startup, so this is a belt-and-braces label
            // rather than the one the rep sees.
            channel.id,
            importance: silent ? Importance.low : importance,
            priority: _priority(channel.importance),
            playSound: !silent,
            // Shade grouping. `group_key` is server-supplied
            // (`Assignment:{routeId}`), so a burst of edits to one route
            // replaces itself instead of stacking (§9.3).
            tag: groupKey,
            groupKey: groupKey,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: !silent,
            presentSound: !silent,
            // The badge is authoritative from the server (`aps.badge`), so a
            // locally-drawn alert must not touch it — incrementing here would
            // double-count an item the server already counted.
            presentBadge: false,
            threadIdentifier: groupKey,
          ),
        ),
        payload: payload,
      );
    } catch (error) {
      _logger.warning('local_notifications.show_failed', fields: {
        // Never the title or body: a notification body can name a depot, and
        // `docs/skills/security.md` §10 keeps depot information out of logs.
        'channel': channel.id,
        'error': error.runtimeType.toString(),
      });
    }
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        // `checkPermissions` is the read-only query; requesting here would
        // prompt, which §14 forbids outside the explainer.
        final permissions = await ios.checkPermissions();
        return permissions?.isEnabled ?? false;
      }
      return false;
    } catch (error) {
      // Unknown is reported as "not enabled": the caller uses this to decide
      // whether to bother composing an alert, and a wasted skip is cheaper than
      // an exception on a screen.
      _logger.warning('local_notifications.enabled_check_failed',
          fields: {'error': error.runtimeType.toString()});
      return false;
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (error) {
      _logger.warning('local_notifications.cancel_all_failed',
          fields: {'error': error.runtimeType.toString()});
    }
  }

  Importance _importance(NotificationChannelImportance value) =>
      switch (value) {
        NotificationChannelImportance.min => Importance.min,
        NotificationChannelImportance.low => Importance.low,
        NotificationChannelImportance.standard => Importance.defaultImportance,
        NotificationChannelImportance.high => Importance.high,
      };

  /// Android's legacy pre-channel priority. Still honoured on API < 26, which
  /// this app supports (`minSdk` is Flutter's floor of 21).
  Priority _priority(NotificationChannelImportance value) => switch (value) {
        NotificationChannelImportance.min => Priority.min,
        NotificationChannelImportance.low => Priority.low,
        NotificationChannelImportance.standard => Priority.defaultPriority,
        NotificationChannelImportance.high => Priority.high,
      };
}

/// Builds the native presenter. Selected by
/// `local_notification_presenter_factory.dart` on Android and iOS.
LocalNotificationPresenter createLocalNotificationPresenter(AppLogger logger) =>
    NativeLocalNotificationPresenter(logger);
