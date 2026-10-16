/// The Android notification channels this app owns
/// (`docs/feature/notification/README.md` §9.3).
///
/// ## Why these must exist before the first push
///
/// The backend stamps `android.notification.channel_id` on every push. Android
/// will not create a channel on demand — a push naming one that does not exist
/// is dropped into a default channel the rep cannot see or control, so their
/// per-category OS settings silently stop working and a mis-tagged P1 arrives
/// with no sound. Channels are therefore created at startup, before any message
/// can arrive, by `NotificationChannelRegistrar`.
///
/// A channel's importance is also **immutable after creation**: Android ignores
/// any later change so a user's own adjustment can never be overridden by an
/// app update. Correcting one in a future release needs a new channel id, not a
/// new importance value here.
///
/// ## Why this lives in `core/` keyed by a raw string
///
/// The channel table has to exist at boot, before any feature is resolved, and
/// `core/` must not import a feature (`docs/blueprint/system-architecture.md` §2). So the key is
/// the wire category code (`ASSIGNMENT`) rather than the notification feature's
/// enum, and the feature maps its enum onto it.
library;

/// How loudly a channel announces itself. Mirrors Android's `IMPORTANCE_*`
/// constants without importing the plugin, so this file stays dependency-free
/// and usable from a test that never boots Flutter.
enum NotificationChannelImportance {
  /// Silent, no status-bar icon. Nothing in this app uses it — a notification
  /// nobody can see is not worth raising.
  min,

  /// Status bar only, no sound. KPI digests.
  low,

  /// Sound, no heads-up banner.
  standard,

  /// Sound and a heads-up banner. Assignments, finance, approvals, security.
  high,
}

/// One channel definition.
class NotificationChannel {
  const NotificationChannel({
    required this.id,
    required this.categoryCode,
    required this.importance,
    required this.nameKey,
    required this.descriptionKey,
  });

  /// The id the backend addresses. **Never change one of these** — Android keys
  /// the user's own per-channel settings by it, so a renamed id silently resets
  /// every rep's choices and orphans the old channel in their system settings.
  final String id;

  /// The wire category code this channel serves, e.g. `ASSIGNMENT`.
  final String categoryCode;

  final NotificationChannelImportance importance;

  /// Localisation key for the name the rep sees in Android system settings.
  ///
  /// Resolved at registration time, in the active language. Note the OS caches
  /// what it was given: switching the app's language re-registers the channels,
  /// but Android keeps the *original* name for an existing channel id, so a
  /// rep who switches to Khmer sees Khmer channel names only after a reinstall.
  /// That is an Android constraint, not an oversight — renaming via a new id
  /// would reset their settings, which is worse.
  final String nameKey;

  final String descriptionKey;
}

/// The ten channels of §9.3, one per category.
///
/// Importance is taken verbatim from that table rather than derived from the
/// priority tier: the two are different axes. Priority is per-notification and
/// already applied server-side; channel importance is per-category and is the
/// rep's own OS-level control over a whole class of message.
abstract final class NotificationChannels {
  const NotificationChannels._();

  static const NotificationChannel assignment = NotificationChannel(
    id: 'assignment',
    categoryCode: 'ASSIGNMENT',
    importance: NotificationChannelImportance.high,
    nameKey: 'notifications.channel.assignment.name',
    descriptionKey: 'notifications.channel.assignment.description',
  );

  static const NotificationChannel quotes = NotificationChannel(
    id: 'quotes',
    categoryCode: 'QUOTE',
    importance: NotificationChannelImportance.standard,
    nameKey: 'notifications.channel.quotes.name',
    descriptionKey: 'notifications.channel.quotes.description',
  );

  static const NotificationChannel orders = NotificationChannel(
    id: 'orders',
    categoryCode: 'ORDER',
    importance: NotificationChannelImportance.standard,
    nameKey: 'notifications.channel.orders.name',
    descriptionKey: 'notifications.channel.orders.description',
  );

  static const NotificationChannel finance = NotificationChannel(
    id: 'finance',
    categoryCode: 'FINANCE',
    importance: NotificationChannelImportance.high,
    nameKey: 'notifications.channel.finance.name',
    descriptionKey: 'notifications.channel.finance.description',
  );

  static const NotificationChannel approvals = NotificationChannel(
    id: 'approvals',
    categoryCode: 'APPROVAL',
    importance: NotificationChannelImportance.high,
    nameKey: 'notifications.channel.approvals.name',
    descriptionKey: 'notifications.channel.approvals.description',
  );

  static const NotificationChannel kpi = NotificationChannel(
    id: 'kpi',
    categoryCode: 'KPI',
    importance: NotificationChannelImportance.low,
    nameKey: 'notifications.channel.kpi.name',
    descriptionKey: 'notifications.channel.kpi.description',
  );

  static const NotificationChannel account = NotificationChannel(
    id: 'account',
    categoryCode: 'ACCOUNT',
    importance: NotificationChannelImportance.standard,
    nameKey: 'notifications.channel.account.name',
    descriptionKey: 'notifications.channel.account.description',
  );

  /// Also the manifest's `default_notification_channel_id`: where a push with
  /// no channel, or an unrecognised one, lands.
  static const NotificationChannel system = NotificationChannel(
    id: 'system',
    categoryCode: 'SYSTEM',
    importance: NotificationChannelImportance.standard,
    nameKey: 'notifications.channel.system.name',
    descriptionKey: 'notifications.channel.system.description',
  );

  static const NotificationChannel announcements = NotificationChannel(
    id: 'announcements',
    categoryCode: 'ANNOUNCE',
    importance: NotificationChannelImportance.standard,
    nameKey: 'notifications.channel.announcements.name',
    descriptionKey: 'notifications.channel.announcements.description',
  );

  static const NotificationChannel security = NotificationChannel(
    id: 'security',
    categoryCode: 'SECURITY',
    importance: NotificationChannelImportance.high,
    nameKey: 'notifications.channel.security.name',
    descriptionKey: 'notifications.channel.security.description',
  );

  /// Every channel, in the order §9.3 tables them. This is what the registrar
  /// walks at startup — a category missing here is a category the rep cannot
  /// control from system settings.
  static const List<NotificationChannel> all = [
    assignment,
    quotes,
    orders,
    finance,
    approvals,
    kpi,
    account,
    system,
    announcements,
    security,
  ];

  /// The channel serving [categoryCode], falling back to [system].
  ///
  /// The fallback matches the manifest's `default_notification_channel_id`, so
  /// an unknown category behaves identically whether the OS resolved it (a
  /// background push) or this code did (a foreground one). Two different
  /// fallbacks for the same condition is how the same notification ends up loud
  /// in one app state and silent in another.
  static NotificationChannel forCategory(String? categoryCode) {
    if (categoryCode == null || categoryCode.isEmpty) return system;
    final normalized = categoryCode.toUpperCase();
    for (final channel in all) {
      if (channel.categoryCode == normalized) return channel;
    }
    return system;
  }

  /// The channel with [id], or null. For validating a `channel_id` the backend
  /// sent before trusting it.
  static NotificationChannel? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final channel in all) {
      if (channel.id == id) return channel;
    }
    return null;
  }
}
