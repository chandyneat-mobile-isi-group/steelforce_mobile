import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// One page of the inbox, plus the bookkeeping the catch-up loop needs.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.hasMore,
    this.syncTimestamp,
  });

  final List<NotificationMessage> items;
  final bool hasMore;

  /// The server's own clock, from `metadata.syncTimestamp`, and **the only
  /// valid source for the next `since`**.
  ///
  /// `docs/feature/notification/README.md` §6.1 calls substituting the device
  /// clock here *"the single most common way an offline-first notification
  /// client breaks"*: a handset ten minutes fast asks for changes since the
  /// future, gets an empty result, stores that timestamp, and never syncs again
  /// — with no error to notice. Nullable because a malformed or absent metadata
  /// block must leave the previous cursor in place rather than advance it to a
  /// guess.
  final DateTime? syncTimestamp;
}

/// The notification API as the app sees it (§3).
///
/// Every method throws `ApiException` on failure — repositories translate that
/// into a `Failure` so no exception leaks past the data layer
/// (`docs/skills/engineering-standard.md` §7).
abstract interface class NotificationRemoteDataSource {
  /// `GET /mobile/notifications` — the guaranteed delivery path.
  ///
  /// [since] must be a previously returned `syncTimestamp`. Passing null pulls
  /// from the beginning, which is what a first run after sign-in wants.
  ///
  /// No `sort` parameter exists, deliberately (§6.2): an inbox has one useful
  /// order — newest first — and the server's index is built for exactly that.
  Future<NotificationPage> fetchPage({
    DateTime? since,
    int pageNumber = 1,
    int pageSize = 100,
  });

  /// `GET /mobile/notifications/unread-count`.
  ///
  /// The authoritative badge figures, and cheap enough to call on every
  /// foreground. §7: reconcile against these rather than incrementing locally,
  /// because a local counter drifts the first time a push is dropped.
  Future<NotificationCounts> fetchCounts();

  /// `PATCH /mobile/notifications/{id}/read` → 204. Idempotent; the first read
  /// timestamp wins, because that is what the time-to-open metric measures.
  Future<void> markRead(String id);

  /// `PATCH /mobile/notifications/read-all` → the number cleared.
  ///
  /// [categoryCode] scopes it, so the button clears what the rep can see rather
  /// than what they cannot (§8.2).
  Future<int> markAllRead({String? categoryCode});

  /// `POST /mobile/notifications/{id}/action` → 204.
  ///
  /// [occurredAt] is advisory — the server records its own clock — and is used
  /// only to order a replayed offline queue.
  Future<void> recordAction(
    String id, {
    String? actionId,
    DateTime? occurredAt,
  });

  /// `DELETE /mobile/notifications/{id}` → 204, or **409** when the item
  /// requires acknowledgement. A state change, not a deletion.
  Future<void> dismiss(String id);

  /// Runs an action's own `api_call` — `method endpoint` with the bearer token
  /// (§12).
  ///
  /// The endpoint is chosen by the **server**, not composed here: the action
  /// descriptor carries a full path (`/api/v1/routes/{id}/acknowledge`) and this
  /// calls exactly that. Deriving it locally would put a second, divergent copy
  /// of the platform's routing in the client.
  Future<void> invokeAction({required String endpoint, required String method});

  /// `POST /mobile/devices/register`.
  ///
  /// Idempotent on `deviceId`. A registration the backend previously deactivated
  /// because FCM reported the token dead is **revived** by this call, so a rep
  /// never needs an administrator to start receiving notifications again (§4.3).
  Future<PushRegistrationResult> registerDevice(PushRegistration registration);

  /// `DELETE /mobile/devices/{deviceId}` → 204.
  ///
  /// Called *before* the access token is discarded on sign-out (§4.4).
  Future<void> deregisterDevice(String deviceId);

  /// `GET /mobile/notifications/preferences`.
  Future<NotificationPreferences> fetchPreferences();

  /// `PUT /mobile/notifications/preferences` — a whole-document update.
  Future<NotificationPreferences> savePreferences(
      NotificationPreferences preferences);
}
