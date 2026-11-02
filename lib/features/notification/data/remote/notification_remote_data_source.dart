import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// One keyset page of the inbox, newest first.
class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor});

  final List<NotificationMessage> items;

  /// `data.nextCursor`: pass it back as `cursor` for the next, older page.
  /// Opaque — never built or parsed here. Null on the last page.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// The notification API as the app sees it (§3).
///
/// Every method throws `ApiException` on failure — repositories translate that
/// into a `Failure` so no exception leaks past the data layer
/// (`docs/skills/engineering-standard.md` §7).
abstract interface class NotificationRemoteDataSource {
  /// `GET /me/notifications` — the guaranteed delivery path.
  ///
  /// [cursor] is a previous page's `nextCursor`, or null for the newest page.
  /// [limit] is 1–50. [unreadOnly] leaves read notifications out.
  Future<NotificationPage> fetchPage({
    String? cursor,
    int limit = 50,
    bool unreadOnly = false,
  });

  /// `GET /me/notifications/unread-count` — the bell's figure.
  ///
  /// §7: reconcile against this rather than incrementing locally, because a
  /// local counter drifts the first time a push is dropped.
  Future<NotificationCounts> fetchCounts();

  /// `POST /me/notifications/{id}/read` → 204. Idempotent; the first read
  /// time is kept.
  Future<void> markRead(String id);

  /// `POST /me/notifications/read-all` → `data.marked`, how many were unread.
  ///
  /// The endpoint has no category scope; [categoryCode] is ignored by the API
  /// source and only narrows the local mirror.
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
