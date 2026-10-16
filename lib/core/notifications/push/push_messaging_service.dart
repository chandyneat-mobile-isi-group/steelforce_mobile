import 'package:steelforce/core/notifications/push/push_message.dart';

/// The push transport, abstracted so no layer above it imports Firebase.
///
/// Two implementations, selected at compile time by
/// `push_messaging_service_factory.dart`:
///
///  * **native** (`FirebasePushMessagingService`) — Android and iOS.
///  * **web** (`UnsupportedPushMessagingService`) — every method is a
///    well-behaved no-op. A browser build has no FCM registration here (ADR-010)
///    and `firebase_messaging` on web additionally needs a service worker and a
///    VAPID key that this app does not ship. **The inbox is unaffected**, which
///    is exactly the property `docs/feature/notification/README.md` §1 is
///    built around: a dropped push must cost nothing.
///
/// Everything here is safe to call whether or not push is available or
/// permitted. A caller should never have to ask "is this platform supported"
/// before wiring the app up.
abstract interface class PushMessagingService {
  /// True when this build can actually receive a push. False on web.
  bool get isSupported;

  /// Initialises the transport and starts delivering to the streams below.
  ///
  /// Idempotent — §4.1 has registration running on every launch, and the app's
  /// startup path can legitimately be re-entered (a language change rebuilds the
  /// whole widget tree). Must not throw: a Firebase project that is
  /// misconfigured on one platform cannot be allowed to take the app down with
  /// it, because the inbox still works and that is most of the feature.
  Future<void> initialize();

  /// The current FCM registration token, or null when there is none yet — no
  /// permission, no network on first mint, or an unsupported platform.
  ///
  /// **Never use this as the device identifier.** Tokens rotate; installations
  /// do not (§4.2).
  Future<String?> token();

  /// Emits every time FCM rotates the token.
  ///
  /// Wiring this to re-registration is not optional. A rotated token that is
  /// never re-registered is the failure mode with no symptom: the app looks
  /// healthy and is simply unreachable (§4.1).
  Stream<String> get tokenRefreshes;

  /// The OS permission as the platform reports it *now*.
  ///
  /// Queried rather than cached, because the rep can revoke it in system
  /// settings between two launches and a stale "granted" keeps a mute device in
  /// the push audience.
  Future<PushAuthorization> authorization();

  /// Shows the OS prompt.
  ///
  /// Called only from the in-app explainer (§14). On iOS this is a one-shot: a
  /// second call after a denial returns the denial without showing anything.
  Future<PushAuthorization> requestPermission();

  /// Pushes arriving while the app is in the foreground.
  ///
  /// The OS banner is suppressed for these; §10 requires an in-app card
  /// instead, because two alerts for one event is how a rep learns to ignore
  /// both.
  Stream<PushMessage> get onForegroundMessage;

  /// A notification the rep **tapped** while the app was backgrounded.
  Stream<PushMessage> get onMessageOpened;

  /// The notification that cold-started the app, if any.
  ///
  /// **Must be checked at startup or a terminated-state tap is swallowed
  /// entirely** (§10, §16) — the rep taps, the app opens on the home screen, and
  /// the thing they were told about is nowhere. Returns null on every subsequent
  /// call, so the caller reads it exactly once.
  Future<PushMessage?> initialMessage();

  /// Asks the OS to suppress its own banner while the app is in the foreground.
  ///
  /// §10 requires a suppressed banner and an in-app card there; two alerts for
  /// one event is how a rep learns to ignore both. On Android the OS never draws
  /// a banner for a foregrounded app, so this only has an effect on iOS —
  /// `badge` stays on, because the app-icon badge the backend sends in
  /// `aps.badge` is still the right number to show.
  ///
  /// Deliberately **not** an app-icon-badge setter. §5.4 requires the icon badge
  /// to come from `action_required`, and it does: the backend stamps `aps.badge`
  /// and `notification_count` on every push (§9.3), which is the only channel
  /// that can update the badge while the app is not running. Adding a
  /// client-side setter would need a further dependency and could only ever
  /// correct the number while the app is already open — where the in-app badges
  /// are visible anyway.
  Future<void> suppressForegroundAlerts();

  /// Drops the FCM token so this installation stops receiving pushes.
  ///
  /// Belt-and-braces alongside `DELETE /mobile/devices/{deviceId}` on sign-out:
  /// the server call is what actually stops the sends, and this makes sure a
  /// failed sign-out request cannot leave a live token behind on a handset that
  /// has changed hands (§4.4).
  Future<void> deleteToken();
}

/// The OS notification permission, in transport terms.
///
/// Deliberately separate from the domain's `PushPermissionStatus`: this is what
/// the platform said, and that is what the feature decided it means. Collapsing
/// them would put a Firebase concept in the domain layer, which
/// `docs/blueprint/system-architecture.md` §2 forbids.
enum PushAuthorization {
  /// Not asked yet. The explainer is due — and on iOS this is the only state
  /// from which asking can still change anything.
  notDetermined,

  authorized,

  /// iOS provisional authorisation: delivered quietly to Notification Centre
  /// with no prompt. Counts as authorised for the push audience — the message
  /// does arrive.
  provisional,

  /// Declined, but the OS may still prompt again.
  ///
  /// On Android this is the "dismissed / not now" case. §14 allows re-offering
  /// the explainer here, capped at once every 14 days.
  denied,

  /// Declined, and **the OS will not show another prompt**.
  ///
  /// New in `firebase_messaging` 16: on Android 13+ the rep must enable
  /// notifications from system settings, and on Apple platforms permanent
  /// denial is reported as [denied] instead.
  ///
  /// Kept distinct from [denied] because it changes what the UI may honestly
  /// offer. Asking again does nothing, so an "Enable" button here is a control
  /// that silently fails — the rep taps it, no prompt appears, and they
  /// reasonably conclude the app is broken. Only a link to system settings can
  /// change this answer.
  deniedPermanently,

  /// No push transport in this build. Not an error and not a denial: nothing was
  /// ever asked, and nothing can be.
  unsupported,
}
