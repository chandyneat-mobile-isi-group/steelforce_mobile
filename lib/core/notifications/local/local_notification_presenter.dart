import 'package:steelforce/core/notifications/notification_channels.dart';

/// Draws notifications the OS will not draw for us, and owns the ten Android
/// channels the backend addresses by id.
///
/// ## Two distinct jobs
///
/// **1. Channel registration.** `docs/feature/notification/README.md` §9.3
/// requires all ten channels to exist *before* the first push, because Android
/// drops a push naming an unknown channel into a default the rep cannot see or
/// control. This has to happen at startup and cannot be fetched.
///
/// **2. Local alerts.** Three cases need an alert the OS did not produce:
///
///  * a push arriving in the foreground, where §10 wants the OS banner
///    suppressed and something in-app instead — this is the fallback for when
///    the app is foregrounded but the relevant screen is not visible;
///  * the "somebody else already handled that" message the offline action queue
///    shows on a `409 Notification.AlreadyResolved`, which §8.5 requires be told
///    to the rep rather than silently discarded;
///  * anything raised while offline, which by definition never went near FCM.
///
/// Web has neither job — see `local_notification_presenter_web.dart`.
abstract interface class LocalNotificationPresenter {
  /// Prepares the plugin and wires taps back to [onTap], which receives the
  /// payload passed to [show] — the `app://` deep link, or null.
  ///
  /// Deliberately does **not** ask for the OS notification permission: §14 has
  /// that spent by the in-app explainer, once, after the rep has seen why it
  /// matters. A plugin that prompts on initialise would spend iOS's single
  /// prompt on a cold launch.
  Future<void> initialize({required void Function(String? payload) onTap});

  /// Creates or updates every channel in [NotificationChannels.all].
  ///
  /// [translate] resolves a localisation key to display text, injected rather
  /// than imported so this stays free of the localisation singleton and is
  /// testable without loading an asset bundle.
  ///
  /// Safe to call repeatedly. Note Android keeps the *original* name and
  /// importance for an existing channel id — a rep's own adjustment must never
  /// be overridden by an app update — so a re-run after a language change is a
  /// no-op in practice. See [NotificationChannel.nameKey].
  Future<void> registerChannels(String Function(String key) translate);

  /// Shows one alert now.
  ///
  /// [categoryCode] picks the channel via [NotificationChannels.forCategory],
  /// so an unknown category lands in `system` — the same place the manifest's
  /// `default_notification_channel_id` sends it, which keeps a foreground and a
  /// background delivery of the same notification behaving identically.
  ///
  /// [payload] is the deep link a tap should open. [groupKey] maps to Android's
  /// `tag` / iOS's `thread-id` so a burst of edits to one route collapses in the
  /// shade instead of stacking (§9.3).
  Future<void> show({
    required String title,
    required String body,
    String? categoryCode,
    String? payload,
    String? groupKey,
    bool silent = false,
  });

  /// Whether the OS will currently let this app post a notification.
  ///
  /// Distinct from the FCM authorisation state: on Android 13+ a rep can turn
  /// off a single channel, or notifications app-wide, without FCM knowing. Used
  /// to decide whether a local alert is worth composing at all.
  Future<bool> areNotificationsEnabled();

  /// Clears every alert this app has posted. Used on sign-out, so one rep's
  /// notifications do not sit in the shade of a handset that has changed hands.
  Future<void> cancelAll();
}
