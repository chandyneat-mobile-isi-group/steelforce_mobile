import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';

/// The rep's notification settings, which live server-side and follow them
/// across devices (`docs/feature/notification/README.md` §13).
///
/// Cached locally only so the settings screen opens instantly and reads
/// something sensible offline. The cache is never authoritative: a rep who
/// changed a toggle on another handset must see that change here, so a
/// successful [load] always replaces what was stored.
abstract interface class NotificationPreferencesRepository {
  /// `GET /mobile/notifications/preferences`.
  ///
  /// A rep who has never opened this screen still gets a full response with
  /// everything on — §13 is explicit that **absence of a record means
  /// "everything", not "nothing"**.
  ///
  /// Falls back to the last cached document when offline, so the screen renders
  /// rather than showing an error over settings the rep can already see.
  ResultFuture<NotificationPreferences> load();

  /// The cached document without touching the network, or null when this device
  /// has never loaded one. For opening the screen with content already on it.
  Future<NotificationPreferences?> cached();

  /// `PUT /mobile/notifications/preferences` — a whole-document update.
  ///
  /// Categories omitted from [preferences] are left alone server-side. Two
  /// contract rules the implementation must honour rather than discover:
  ///
  ///  * `quietHoursStart` and `quietHoursEnd` go **together or not at all** —
  ///    one without the other answers `400 Notification.QuietHoursIncomplete`.
  ///  * Muting a locked category answers `422 Notification.CategoryNotMutable`
  ///    rather than being silently ignored, so a toggle never snaps back with no
  ///    explanation.
  ///
  /// Deliberately **not** queued for offline replay, unlike inbox mutations.
  /// Preferences are a whole-document overwrite with no merge, so a stale
  /// document replayed after a reconnect would clobber a change the rep made on
  /// another device in the meantime. Failing here and letting them retry is
  /// honest; silently reverting another handset's settings is not.
  ResultFuture<NotificationPreferences> save(
      NotificationPreferences preferences);

  /// Drops the cached document on sign-out — it is rep-scoped.
  Future<void> clear();
}
