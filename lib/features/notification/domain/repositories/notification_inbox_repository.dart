import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/domain/entities/notification_sync_result.dart';

/// The rep's inbox — reads from the local encrypted mirror, writes through to
/// the server when it can and to a queue when it cannot.
///
/// ## Reads are local, always
///
/// [watch] and [counts] answer from the device. `docs/feature/notification/README.md`
/// §1 establishes the inbox as the system of record and push as a mere
/// accelerator; a repository that reached for the network to render a list would
/// show a rep in a warehouse an empty screen and an error banner, which is
/// precisely what the offline-first design exists to prevent (ADR-002 §2).
///
/// ## Writes are local-first
///
/// Every mutation lands in the mirror and enqueues its server call **in the same
/// transaction** (ADR-006, `docs/blueprint/sync-architecture.md` §2). That is a correctness rule,
/// not a style choice: a state change that is visible to the rep but has no
/// queued call is a route the supervisor still thinks was never acknowledged.
abstract interface class NotificationInboxRepository {
  /// The inbox slice matching [query], newest first, as a live stream.
  ///
  /// Always newest first — §6.2 notes there is no `sort` parameter, deliberately:
  /// an inbox has one useful order and the index behind it is built for exactly
  /// that. Items requiring acknowledgement are pinned above the rest (§5.4).
  ///
  /// A stream rather than a future because three things mutate this list behind
  /// the screen's back: a catch-up sync, an arriving push, and the action queue
  /// draining after reconnect.
  Stream<List<NotificationMessage>> watch(NotificationQuery query);

  /// One notification from the local mirror, or null when this device has never
  /// seen it — which happens on a deep link tapped from a push whose catch-up
  /// has not run yet.
  Future<NotificationMessage?> findById(String id);

  /// Live badge figures, read from the mirror.
  ///
  /// Reconciled against `GET /unread-count` by [refreshCounts]; this stream is
  /// what the bell and the app icon bind to so they move the instant a local
  /// state change lands.
  Stream<NotificationCounts> watchCounts();

  /// Pulls everything created after the stored cursor and upserts it.
  ///
  /// Called on app start, on foreground, on pull-to-refresh, on reconnect, and
  /// whenever a push arrives (§6.1). Upserts are keyed on the notification id so
  /// a catch-up that overlaps a push already handled cannot produce a duplicate
  /// row.
  ///
  /// [full] discards the cursor and re-pulls from the beginning — for a first
  /// run after sign-in, or a manual repair.
  ResultFuture<NotificationSyncResult> catchUp({bool full = false});

  /// Re-reads `GET /unread-count` and stores it.
  ///
  /// Cheap enough to call on every foreground, and the only correct source for
  /// the badges — §7 is explicit that reconciling beats incrementing, because a
  /// local counter drifts the first time a push is dropped.
  ResultFuture<NotificationCounts> refreshCounts();

  /// Marks one item read. Local first, then `PATCH /{id}/read`.
  ///
  /// Idempotent and safe to replay: the first read timestamp wins, because that
  /// is what the time-to-open metric measures.
  ResultFuture<void> markRead(String notificationId);

  /// Marks everything read, optionally within one category.
  ///
  /// Pass the category the inbox is currently filtered by, so the button clears
  /// what the rep can see rather than what they cannot (§8.2).
  ResultFuture<int> markAllRead({String? categoryCode});

  /// Records that the rep **acted** — `POST /{id}/action`.
  ///
  /// This is the only call that closes an item requiring acknowledgement.
  /// Reading is not acting: a route assignment that has been read still counts
  /// against the badge and still escalates to a supervisor if it is never
  /// acknowledged (§8.3).
  ///
  /// [actionId] is omitted when the rep acted inside the record rather than from
  /// a notification button.
  ResultFuture<void> recordAction(String notificationId, {String? actionId});

  /// Dismisses one item — `DELETE /{id}`, a state change and not a deletion.
  ///
  /// Fails for an item that requires acknowledgement; the server answers 409 and
  /// the entity refuses locally via `isDismissible`, so the two agree.
  ResultFuture<void> dismiss(String notificationId);

  /// Upserts a notification delivered by push.
  ///
  /// The FCM payload is a **subset** of the inbox object and deliberately
  /// carries no prices, credit limits or phone numbers (§9.2) — a push renders
  /// on a locked screen in front of whoever is holding the phone. So this stores
  /// what arrived and schedules a catch-up to fill in the rest, rather than
  /// treating the push as authoritative.
  ResultFuture<void> upsertFromPush(Map<String, String> data,
      {String? title, String? body});

  /// Replays queued read/action/dismiss calls after a reconnect (§8.5).
  ///
  /// Returns the rows that came back `409 Notification.AlreadyResolved`, so the
  /// caller can tell the rep somebody else got there first instead of
  /// discarding the work silently.
  ResultFuture<List<String>> drainActionQueue();

  /// Clears every locally-mirrored notification and every queued call.
  ///
  /// Called on sign-out: the inbox is rep-scoped, and leaving one rep's
  /// notifications on a handset that has been handed to somebody else is a
  /// disclosure, not an inconvenience.
  Future<void> clear();
}
