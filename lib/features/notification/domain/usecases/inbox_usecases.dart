import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/domain/entities/notification_sync_result.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_inbox_repository.dart';

/// The inbox use cases.
///
/// ## Why several classes share one file
///
/// The house convention is one use case per file, and it earns its keep where a
/// use case carries logic worth reading on its own. These eleven do not: each is
/// a named, single-purpose entry point onto one repository, and the important
/// reading — why a read is local, why a write is queued, why a 409 is not
/// retried — lives in `NotificationInboxRepository` and its implementation
/// where it belongs. Eleven files averaging six lines would scatter the seam
/// without adding a single sentence anyone needs.
///
/// The rule that actually matters is intact and is the reason these are not
/// collapsed into fewer classes: **one use case per business action**, no
/// branching on a "mode" parameter. Marking read, recording an action and
/// dismissing are three different things to the server and to a supervisor's
/// escalation chain (`docs/feature/notification/README.md` §8.3), so they are
/// three types.

/// The inbox slice matching a query, live.
///
/// A stream, not a future: three things mutate this list behind the screen's
/// back — a catch-up sync, an arriving push, and the action queue draining after
/// a reconnect.
class WatchNotifications
    implements StreamUseCase<List<NotificationMessage>, NotificationQuery> {
  const WatchNotifications(this._repository);

  final NotificationInboxRepository _repository;

  @override
  Stream<List<NotificationMessage>> call(NotificationQuery params) =>
      _repository.watch(params);
}

/// Live badge figures — the bell, the tab badge and the per-category counts.
class WatchNotificationCounts
    implements StreamUseCase<NotificationCounts, NoParams> {
  const WatchNotificationCounts(this._repository);

  final NotificationInboxRepository _repository;

  @override
  Stream<NotificationCounts> call(NoParams params) => _repository.watchCounts();
}

/// One notification by id — for a deep link that arrived before its catch-up.
class GetNotificationById {
  const GetNotificationById(this._repository);

  final NotificationInboxRepository _repository;

  Future<NotificationMessage?> call(String id) => _repository.findById(id);
}

/// Pulls everything created since the stored cursor.
///
/// §6.1: run this on app start, on foreground, on pull-to-refresh, on reconnect,
/// and whenever a push arrives. It is the guaranteed delivery path — the reason a
/// dropped push costs nothing.
class SyncNotifications
    implements UseCase<NotificationSyncResult, SyncNotificationsParams> {
  const SyncNotifications(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<NotificationSyncResult> call(SyncNotificationsParams params) =>
      _repository.catchUp(full: params.full);
}

class SyncNotificationsParams extends Equatable {
  const SyncNotificationsParams({this.full = false});

  /// Discards the cursor and re-pulls from the beginning.
  ///
  /// Needed for more than a repair: the stored title and body were localised
  /// server-side against the `Accept-Language` header in force when they were
  /// pulled, so a rep switching to Khmer needs a full re-pull to see existing
  /// rows in Khmer rather than only new ones.
  final bool full;

  static const SyncNotificationsParams delta = SyncNotificationsParams();
  static const SyncNotificationsParams full_ =
      SyncNotificationsParams(full: true);

  @override
  List<Object?> get props => [full];
}

/// Re-reads `GET /unread-count` and stores it.
///
/// §7: reconcile against the server rather than incrementing locally. Cheap
/// enough to call on every foreground.
class RefreshNotificationCounts
    implements UseCase<NotificationCounts, NoParams> {
  const RefreshNotificationCounts(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<NotificationCounts> call(NoParams params) =>
      _repository.refreshCounts();
}

/// Marks one item read.
///
/// Wire this to "the rep opened it" — and **only** that. Wiring it to a
/// scroll-past is correct; wiring a scroll-past to [RecordNotificationAction] is
/// what silently breaks the escalation chain (§8.3).
class MarkNotificationRead implements UseCase<void, String> {
  const MarkNotificationRead(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<void> call(String params) => _repository.markRead(params);
}

/// Marks everything read, optionally within one category.
class MarkAllNotificationsRead
    implements UseCase<int, MarkAllNotificationsReadParams> {
  const MarkAllNotificationsRead(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<int> call(MarkAllNotificationsReadParams params) =>
      _repository.markAllRead(categoryCode: params.categoryCode);
}

class MarkAllNotificationsReadParams extends Equatable {
  const MarkAllNotificationsReadParams({this.categoryCode});

  /// Pass whatever the inbox is filtered by, so the button clears what the rep
  /// can see rather than what they cannot (§8.2).
  final String? categoryCode;

  @override
  List<Object?> get props => [categoryCode];
}

/// Records that the rep **acted**.
///
/// The only thing that closes an item requiring acknowledgement. Reading is not
/// acting: a route assignment that has been read still counts against the badge
/// and still escalates to a supervisor if it is never acknowledged (§8.3).
class RecordNotificationAction
    implements UseCase<void, RecordNotificationActionParams> {
  const RecordNotificationAction(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<void> call(RecordNotificationActionParams params) => _repository
      .recordAction(params.notificationId, actionId: params.actionId);
}

class RecordNotificationActionParams extends Equatable {
  const RecordNotificationActionParams({
    required this.notificationId,
    this.actionId,
  });

  final String notificationId;

  /// Omitted when the rep acted inside the record rather than from a
  /// notification button, which §8.3 explicitly allows.
  final String? actionId;

  @override
  List<Object?> get props => [notificationId, actionId];
}

/// Dismisses one item — a state change, not a deletion. Refused for an item that
/// requires acknowledgement.
class DismissNotification implements UseCase<void, String> {
  const DismissNotification(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<void> call(String params) => _repository.dismiss(params);
}

/// Replays queued read/action/dismiss calls after a reconnect (§8.5).
///
/// Returns the notification ids that came back
/// `409 Notification.AlreadyResolved`, so the caller can tell the rep somebody
/// else got there first rather than discarding their work silently.
class DrainNotificationActions implements UseCase<List<String>, NoParams> {
  const DrainNotificationActions(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<List<String>> call(NoParams params) =>
      _repository.drainActionQueue();
}

/// Stores a notification delivered by push, then triggers a catch-up to
/// complete it — the push is a deliberate subset (§9.2).
class IngestPushNotification
    implements UseCase<void, IngestPushNotificationParams> {
  const IngestPushNotification(this._repository);

  final NotificationInboxRepository _repository;

  @override
  ResultFuture<void> call(IngestPushNotificationParams params) => _repository
      .upsertFromPush(params.data, title: params.title, body: params.body);
}

class IngestPushNotificationParams extends Equatable {
  const IngestPushNotificationParams({
    required this.data,
    this.title,
    this.body,
  });

  /// String-only, mirroring the FCM `data` block (§9.1).
  final Map<String, String> data;
  final String? title;
  final String? body;

  @override
  List<Object?> get props => [data, title, body];
}

/// Drops every locally-mirrored notification and every queued call.
///
/// Sign-out only. An inbox is rep-scoped PII, and a queued acknowledgement made
/// by one rep must never replay under the next rep's token.
class ClearNotifications {
  const ClearNotifications(this._repository);

  final NotificationInboxRepository _repository;

  Future<void> call() => _repository.clear();
}
