import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/notification_tables.dart';

part 'notification_dao.g.dart';

/// The one write path into the notification inbox mirror and its outbox
/// (ADR-004, `docs/blueprint/local-storage-architecture.md` §4).
///
/// ## The transactional rule this DAO exists to enforce
///
/// Every method that changes a notification's state also enqueues the server
/// call for it, **inside one transaction** — ADR-006 and
/// `docs/blueprint/sync-architecture.md` §2 make that a correctness requirement, not a style
/// preference. Splitting them means a state the rep can see with no call queued
/// to match it: a route the supervisor still believes was never acknowledged, or
/// a badge that never clears server-side.
///
/// The API is therefore deliberately coarse. There is no "set state" and no
/// "enqueue" — only [markRead], [recordAction] and [dismiss], each of which does
/// both halves. A caller cannot do one without the other because it is never
/// offered the choice.
///
/// ## Cursor scope
///
/// The `inbox` cursor and the reconciled counts live in the same database as the
/// rows, so [clearAll] drops all three in one transaction. A cursor outliving
/// its rows asks the server for "changes since" a point whose rows are gone,
/// gets an empty delta, and leaves a permanently blank inbox with no error.
@DriftAccessor(
    tables: [Notifications, NotificationActionQueue, NotificationSyncMeta])
class NotificationDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationDaoMixin {
  NotificationDao(super.db);

  /// The single cursor row's key. One stream today; the table is keyed so a
  /// second needs no migration.
  static const String inboxEntity = 'inbox';

  // ── Reads ───────────────────────────────────────────────────────────

  /// Watches the inbox slice matching the filters, newest first.
  ///
  /// Ordering is `requires_ack DESC, created_at DESC`: §5.4 pins outstanding
  /// actions to the top, and §6.2 fixes everything else as newest-first —
  /// deliberately, since an inbox has one useful order and
  /// `idx_notifications_state` is built for exactly that.
  ///
  /// [requiresAckOnly] narrows to the **Action needed** tab. It is a separate
  /// flag rather than another state value because an item awaiting
  /// acknowledgement can be unread *or* read and is outstanding either way —
  /// reading is not acting (§8.3).
  Stream<List<NotificationRow>> watchInbox({
    required Set<String> states,
    bool requiresAckOnly = false,
    String? categoryCode,
    int limit = 60,
  }) {
    final query = select(notifications)
      ..where((t) => t.state.isIn(states))
      ..orderBy([
        (t) => OrderingTerm(expression: t.requiresAck, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    if (requiresAckOnly) {
      query.where((t) => t.requiresAck.equals(true));
    }
    if (categoryCode != null) {
      query.where((t) => t.category.equals(categoryCode));
    }

    return query.watch();
  }

  Future<NotificationRow?> findById(String id) =>
      (select(notifications)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Watches the persisted cursor/count row. Emits null until the first sync
  /// writes it, which is the honest answer for a device that has never synced.
  Stream<NotificationSyncMetaRow?> watchSyncMeta() =>
      (select(notificationSyncMeta)..where((t) => t.entity.equals(inboxEntity)))
          .watchSingleOrNull();

  Future<NotificationSyncMetaRow?> syncMeta() =>
      (select(notificationSyncMeta)..where((t) => t.entity.equals(inboxEntity)))
          .getSingleOrNull();

  /// A live view of everything the badge calculation needs, from all three
  /// tables at once.
  ///
  /// ## Why one custom query rather than three watched selects
  ///
  /// The badge has to move on **any** of three events: a catch-up storing rows,
  /// the rep reading one, and a reconcile writing the server's figures. Drift
  /// invalidates a `customSelect` whenever any table in [readsFrom] changes, so
  /// this single stream covers all three. Watching only `notification_sync_meta`
  /// — the obvious first attempt — leaves the bell frozen until the next
  /// reconcile, so tapping a notification appears to do nothing.
  ///
  /// It returns the raw ingredients rather than a finished number: deciding how
  /// the server's figures and the undrained local changes combine is a domain
  /// question, and it lives in `NotificationInboxRepositoryImpl.watchCounts`.
  Stream<NotificationCountsSnapshot> watchCountsSnapshot() {
    return customSelect(
      '''
SELECT
  (SELECT COUNT(*) FROM notifications WHERE state = 'unread')
    AS local_unread,
  (SELECT COUNT(*) FROM notifications
     WHERE requires_ack = 1 AND state IN ('unread', 'read'))
    AS local_action_required,
  (SELECT COUNT(*) FROM notification_action_queue WHERE kind = 'read')
    AS pending_reads,
  (SELECT COUNT(*) FROM notification_action_queue WHERE kind = 'read_all')
    AS pending_read_all,
  (SELECT COUNT(*) FROM notification_action_queue WHERE kind = 'action')
    AS pending_actions,
  (SELECT unread FROM notification_sync_meta WHERE entity = ?)
    AS server_unread,
  (SELECT action_required FROM notification_sync_meta WHERE entity = ?)
    AS server_action_required,
  (SELECT by_category_json FROM notification_sync_meta WHERE entity = ?)
    AS by_category_json,
  (SELECT counts_at FROM notification_sync_meta WHERE entity = ?)
    AS counts_at;
''',
      variables: List.filled(4, Variable<String>(inboxEntity)),
      readsFrom: {notifications, notificationActionQueue, notificationSyncMeta},
    ).watchSingle().map((row) {
      return NotificationCountsSnapshot(
        localUnread: row.read<int>('local_unread'),
        localActionRequired: row.read<int>('local_action_required'),
        pendingReads: row.read<int>('pending_reads'),
        pendingReadAll: row.read<int>('pending_read_all'),
        pendingActions: row.read<int>('pending_actions'),
        serverUnread: row.read<int?>('server_unread'),
        serverActionRequired: row.read<int?>('server_action_required'),
        byCategoryJson: row.read<String?>('by_category_json'),
        // Read through drift's own type mapping rather than decoding the raw
        // column. A `DateTimeColumn` is stored as unix seconds *or* as ISO text
        // depending on `store_date_time_values_as_text` in `build.yaml`, and
        // hand-decoding one shape throws a `FormatException` the day the other
        // is configured — from inside the badge stream, which would take the
        // bell down app-wide.
        countsAt: row.read<DateTime?>('counts_at')?.toUtc(),
      );
    });
  }

  /// Locally-derived counts, for the window between a state change and the next
  /// server reconcile.
  ///
  /// §7 requires reconciling against `GET /unread-count` rather than
  /// incrementing locally, and this does not contradict that: it is a *derived*
  /// count over the rows actually held, not a counter being nudged. It moves the
  /// badge the instant the rep taps and is replaced wholesale by the next
  /// reconcile.
  Future<({int unread, int actionRequired})> localCounts() async {
    final unread = await _count(
      (t) => t.state.equals('unread'),
    );
    // Outstanding, not unread: an item requiring acknowledgement counts until it
    // is actioned, whether or not it has been read.
    final actionRequired = await _count(
      (t) =>
          t.requiresAck.equals(true) & t.state.isIn(const ['unread', 'read']),
    );
    return (unread: unread, actionRequired: actionRequired);
  }

  Future<int> _count(
      Expression<bool> Function($NotificationsTable t) filter) async {
    final countExpression = notifications.id.count();
    final query = selectOnly(notifications)
      ..addColumns([countExpression])
      ..where(filter(notifications));
    final row = await query.getSingleOrNull();
    return row?.read(countExpression) ?? 0;
  }

  // ── Sync writes ─────────────────────────────────────────────────────

  /// Upserts a page of notifications and advances the cursor, in one
  /// transaction.
  ///
  /// [cursor] must be the server's `metadata.syncTimestamp` (§6.1). It is
  /// written in the same transaction as the rows it describes so a crash between
  /// the two cannot advance the cursor past rows that were never stored — which
  /// would skip them permanently, silently.
  ///
  /// Local state wins over the server copy for a row the rep has already acted
  /// on but whose queue row has not drained yet. Without that, a catch-up
  /// running before the queue drains would overwrite an acknowledgement with the
  /// server's stale `unread` and the item would pop back into the rep's Action
  /// needed tab — visibly undoing work they had done.
  Future<void> upsertPage(
    List<NotificationRow> rows, {
    DateTime? cursor,
  }) {
    return transaction(() async {
      final pending = await _pendingNotificationIds();

      for (final row in rows) {
        if (pending.contains(row.id)) {
          // Everything except the lifecycle columns is refreshed, so the rep
          // still gets the corrected title, actions and deep link.
          await (update(notifications)..where((t) => t.id.equals(row.id)))
              .write(
            NotificationsCompanion(
              eventCode: Value(row.eventCode),
              category: Value(row.category),
              priority: Value(row.priority),
              title: Value(row.title),
              body: Value(row.body),
              imageUrl: Value(row.imageUrl),
              deepLink: Value(row.deepLink),
              requiresAck: Value(row.requiresAck),
              expiresAt: Value(row.expiresAt),
              groupKey: Value(row.groupKey),
              badge: Value(row.badge),
              actionsJson: Value(row.actionsJson),
              dataJson: Value(row.dataJson),
              deliveredAt: Value(row.deliveredAt),
              partial: const Value(false),
            ),
          );
          continue;
        }
        await into(notifications).insertOnConflictUpdate(row);
      }

      if (cursor != null) await _writeCursor(cursor);
    });
  }

  /// Writes a row assembled from an FCM payload.
  ///
  /// Marked `partial` because the push deliberately withholds prices, credit
  /// limits, phone numbers and the actions array (§9.2) — a push renders on a
  /// locked screen in front of whoever holds the phone. It must never overwrite
  /// a complete row the inbox endpoint already delivered, or a tap would find a
  /// notification with its action buttons missing.
  Future<void> upsertFromPush(NotificationRow row) {
    return transaction(() async {
      final existing = await findById(row.id);
      if (existing != null && !existing.partial) {
        // The complete record is already here. A push adds nothing except,
        // possibly, a fresher badge snapshot.
        if (row.badge != null && row.badge != existing.badge) {
          await (update(notifications)..where((t) => t.id.equals(row.id)))
              .write(NotificationsCompanion(badge: Value(row.badge)));
        }
        return;
      }
      await into(notifications).insertOnConflictUpdate(row);
    });
  }

  /// Replaces the reconciled badge figures from `GET /unread-count`.
  Future<void> writeCounts({
    required int unread,
    required int actionRequired,
    required String byCategoryJson,
    required DateTime at,
  }) {
    return into(notificationSyncMeta).insertOnConflictUpdate(
      NotificationSyncMetaCompanion.insert(
        entity: inboxEntity,
        unread: Value(unread),
        actionRequired: Value(actionRequired),
        byCategoryJson: Value(byCategoryJson),
        countsAt: Value(at),
      ),
    );
  }

  // ── State changes (mirror + outbox, one transaction each) ───────────

  /// Marks one item read locally and queues `PATCH /{id}/read`.
  ///
  /// A no-op for an item that is not `unread`: the first read timestamp wins,
  /// because that is what the time-to-open metric measures, and re-queueing a
  /// second read would replace it.
  Future<bool> markRead(String notificationId, String queueId, DateTime at) {
    return transaction(() async {
      final row = await findById(notificationId);
      if (row == null || row.state != 'unread') return false;

      await (update(notifications)..where((t) => t.id.equals(notificationId)))
          .write(NotificationsCompanion(
        state: const Value('read'),
        readAt: Value(row.readAt ?? at),
      ));

      await _enqueue(
        id: queueId,
        notificationId: notificationId,
        kind: 'read',
        occurredAt: at,
      );
      return true;
    });
  }

  /// Marks every currently-live item read and queues one `PATCH /read-all`.
  ///
  /// One queue row rather than N: the endpoint is a single bulk call, and
  /// queueing per item would replay a hundred requests after a reconnect to
  /// achieve what one does.
  Future<int> markAllRead({
    required String queueId,
    required DateTime at,
    String? categoryCode,
  }) {
    return transaction(() async {
      final statement = update(notifications)
        ..where((t) => t.state.equals('unread'));
      if (categoryCode != null) {
        statement.where((t) => t.category.equals(categoryCode));
      }
      final affected = await statement.write(NotificationsCompanion(
        state: const Value('read'),
        readAt: Value(at),
      ));

      // Nothing was unread, so there is nothing for the server to do either.
      // Queueing an empty read-all would spend a request to change no rows.
      if (affected == 0) return 0;

      await _enqueue(
        id: queueId,
        // Not scoped to one notification.
        notificationId: '',
        kind: 'read_all',
        occurredAt: at,
        category: categoryCode,
      );
      return affected;
    });
  }

  /// Records that the rep acted, and queues `POST /{id}/action`.
  ///
  /// This is the only transition that closes an item requiring
  /// acknowledgement. Terminal states are left alone: an item already
  /// `resolved_elsewhere` must not be rewritten to look as though this rep
  /// closed it.
  Future<bool> recordAction(
    String notificationId,
    String queueId,
    DateTime at, {
    String? actionId,
  }) {
    return transaction(() async {
      final row = await findById(notificationId);
      if (row == null) return false;
      if (_isClosed(row.state)) return false;

      await (update(notifications)..where((t) => t.id.equals(notificationId)))
          .write(NotificationsCompanion(
        state: const Value('actioned'),
        readAt: Value(row.readAt ?? at),
        actionedAt: Value(row.actionedAt ?? at),
      ));

      await _enqueue(
        id: queueId,
        notificationId: notificationId,
        kind: 'action',
        actionId: actionId,
        occurredAt: at,
      );
      return true;
    });
  }

  /// Dismisses one item and queues `DELETE /{id}`.
  ///
  /// Refuses an item that requires acknowledgement, matching the server's 409
  /// (§5.4) — so the swipe gesture and the endpoint agree, and the rep never
  /// sees a row vanish and reappear.
  Future<bool> dismiss(String notificationId, String queueId, DateTime at) {
    return transaction(() async {
      final row = await findById(notificationId);
      if (row == null || row.requiresAck || _isClosed(row.state)) return false;

      await (update(notifications)..where((t) => t.id.equals(notificationId)))
          .write(NotificationsCompanion(
        state: const Value('dismissed'),
        readAt: Value(row.readAt ?? at),
      ));

      await _enqueue(
        id: queueId,
        notificationId: notificationId,
        kind: 'dismiss',
        occurredAt: at,
      );
      return true;
    });
  }

  /// Forces a notification into `resolved_elsewhere` — no queue row.
  ///
  /// Used when a replayed action comes back `409 Notification.AlreadyResolved`:
  /// somebody else decided first, so the local state is corrected and nothing is
  /// re-sent. §8.3 is explicit — refresh, tell the rep, **do not retry**.
  Future<void> markResolvedElsewhere(String notificationId) {
    return (update(notifications)..where((t) => t.id.equals(notificationId)))
        .write(
            const NotificationsCompanion(state: Value('resolved_elsewhere')));
  }

  /// Drops a notification the server says is gone (`404 Notification.NotFound`
  /// — not yours, or never existed). The only hard delete in this DAO, and it is
  /// removing a row that should not be here rather than discarding history.
  Future<void> deleteById(String notificationId) =>
      (delete(notifications)..where((t) => t.id.equals(notificationId))).go();

  // ── Outbox ──────────────────────────────────────────────────────────

  /// Queued calls, oldest first.
  ///
  /// Order matters: a `read` captured before an `action` on the same item must
  /// replay in that order, or the server records a read timestamp *after* the
  /// action and the time-to-open metric reads as negative.
  Future<List<NotificationActionQueueRow>> pendingActions() =>
      (select(notificationActionQueue)
            ..orderBy([
              (t) => OrderingTerm(expression: t.occurredAt),
              (t) => OrderingTerm(expression: t.createdAt),
            ]))
          .get();

  Future<void> removeQueued(String queueId) =>
      (delete(notificationActionQueue)..where((t) => t.id.equals(queueId)))
          .go();

  Future<void> recordAttempt(String queueId, int attempts) =>
      (update(notificationActionQueue)..where((t) => t.id.equals(queueId)))
          .write(NotificationActionQueueCompanion(attempts: Value(attempts)));

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Drops every notification, every queued call and the cursor, in one
  /// transaction.
  ///
  /// Called on sign-out. All three go together: an inbox is rep-scoped PII, a
  /// queued acknowledgement belongs to the rep who made it and must not be
  /// replayed under the next rep's token, and a surviving cursor would leave the
  /// next rep's inbox permanently empty.
  Future<void> clearAll() {
    return transaction(() async {
      await delete(notifications).go();
      await delete(notificationActionQueue).go();
      await delete(notificationSyncMeta).go();
    });
  }

  /// Ids with an undrained state change, so a catch-up cannot overwrite them.
  Future<Set<String>> _pendingNotificationIds() async {
    final rows = await select(notificationActionQueue).get();
    return rows
        .map((r) => r.notificationId)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> _enqueue({
    required String id,
    required String notificationId,
    required String kind,
    required DateTime occurredAt,
    String? actionId,
    String? category,
  }) {
    return into(notificationActionQueue).insert(
      NotificationActionQueueCompanion.insert(
        id: id,
        notificationId: notificationId,
        kind: kind,
        actionId: Value(actionId),
        category: Value(category),
        occurredAt: occurredAt,
      ),
    );
  }

  Future<void> _writeCursor(DateTime cursor) {
    // `insertOnConflictUpdate` on the whole row would reset the stored counts to
    // their column defaults, blanking the badge until the next reconcile. An
    // update-then-insert keeps them.
    return transaction(() async {
      final affected = await (update(notificationSyncMeta)
            ..where((t) => t.entity.equals(inboxEntity)))
          .write(NotificationSyncMetaCompanion(syncTimestamp: Value(cursor)));
      if (affected > 0) return;
      await into(notificationSyncMeta).insert(
        NotificationSyncMetaCompanion.insert(
          entity: inboxEntity,
          syncTimestamp: Value(cursor),
        ),
      );
    });
  }

  /// The four closed states of §5.1. A local mirror of
  /// `NotificationState.isClosed` — the DAO cannot import the domain enum
  /// (`docs/blueprint/system-architecture.md` §2: inward dependencies only), and
  /// `notification_dao_test.dart` asserts the two lists stay identical so they
  /// cannot drift apart silently.
  static const Set<String> closedStates = {
    'actioned',
    'dismissed',
    'expired',
    'resolved_elsewhere',
  };

  bool _isClosed(String state) => closedStates.contains(state);
}

/// The raw inputs to the badge calculation, read in one shot from all three
/// notification tables.
///
/// Deliberately dumb: it reports what is stored — the server's last reconciled
/// figures, what the local mirror holds, and what has been changed locally but
/// not yet drained — and takes no view on how they combine. That decision is
/// §7's, and it lives in the repository.
class NotificationCountsSnapshot {
  const NotificationCountsSnapshot({
    required this.localUnread,
    required this.localActionRequired,
    required this.pendingReads,
    required this.pendingReadAll,
    required this.pendingActions,
    this.serverUnread,
    this.serverActionRequired,
    this.byCategoryJson,
    this.countsAt,
  });

  /// Derived from the rows this device actually holds. **Undercounts** whenever
  /// the mirror is behind the server, which is the normal state on a fresh
  /// install and after a long time offline.
  final int localUnread;
  final int localActionRequired;

  /// Queued `PATCH /read` calls — reads the server does not know about yet.
  final int pendingReads;

  /// A queued `PATCH /read-all`, which clears everything the server has.
  final int pendingReadAll;

  /// Queued `POST /action` calls — outstanding items the rep has closed but the
  /// server still counts.
  final int pendingActions;

  /// The last figures from `GET /unread-count`. Null until the first reconcile.
  final int? serverUnread;
  final int? serverActionRequired;

  final String? byCategoryJson;
  final DateTime? countsAt;

  /// True before the first reconcile, when the server's figures are unknown and
  /// the local mirror is all there is.
  bool get hasNoServerFigures => serverUnread == null;
}
