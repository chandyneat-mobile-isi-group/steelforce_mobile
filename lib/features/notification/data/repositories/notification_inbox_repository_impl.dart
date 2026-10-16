import 'dart:async';
import 'dart:convert';

import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/database/drift/daos/notification_dao.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/notification/data/models/notification_api_mapper.dart';
import 'package:steelforce/features/notification/data/models/notification_drift_mappers.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/domain/entities/notification_sync_result.dart';
import 'package:steelforce/features/notification/domain/entities/queued_notification_action.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_inbox_repository.dart';

/// The inbox, backed by the encrypted local mirror and reconciled with the API.
///
/// ## The shape of every write
///
/// 1. Mutate the local mirror **and enqueue the server call in one transaction**
///    (the DAO enforces this — ADR-006, `docs/blueprint/sync-architecture.md` §2).
/// 2. Try to drain the queue immediately.
/// 3. Return success either way.
///
/// Step 3 is the part that matters and the part that looks wrong at first
/// glance. A rep acknowledging a route in a warehouse with no signal has done
/// everything asked of them; surfacing a network failure would tell them their
/// work did not count, and they would tap again — producing two acknowledgements
/// of one route. The queue is the promise that it will reach the server, and
/// `docs/blueprint/offline-architecture.md` treats offline as a normal state rather than an error
/// state (ADR-002 §4).
///
/// Failures are returned for the things a rep can actually act on: a refused
/// state change (dismissing an item that requires acknowledgement), and a
/// catch-up that could not run.
class NotificationInboxRepositoryImpl implements NotificationInboxRepository {
  NotificationInboxRepositoryImpl({
    required NotificationDao dao,
    required NotificationRemoteDataSource remote,
    required SessionManager session,
    required AppLogger logger,
  })  : _dao = dao,
        _remote = remote,
        _session = session,
        _logger = logger;

  final NotificationDao _dao;
  final NotificationRemoteDataSource _remote;
  final SessionManager _session;
  final AppLogger _logger;

  /// Guards against two concurrent catch-ups.
  ///
  /// Real, not theoretical: app-resume, a reconnect and an arriving push can all
  /// fire within the same second, and three overlapping runs would page the same
  /// notifications three times and race on the cursor — the later write could
  /// rewind it and re-pull everything on the next run.
  Future<Result<NotificationSyncResult>>? _inFlightCatchUp;

  /// Same guard for the queue drain. Two drains would replay every queued call
  /// twice; the calls are idempotent so nothing corrupts, but it doubles the
  /// requests on exactly the flaky connection that just came back.
  Future<Result<List<String>>>? _inFlightDrain;

  // ── Reads ───────────────────────────────────────────────────────────

  @override
  Stream<List<NotificationMessage>> watch(NotificationQuery query) {
    return _dao
        .watchInbox(
          states: query.states.map((s) => s.code).toSet(),
          requiresAckOnly: query.requiresAckOnly,
          categoryCode: query.category?.code,
          limit: query.limit,
        )
        .map((rows) => rows.map((row) => row.toEntity()).toList());
  }

  @override
  Future<NotificationMessage?> findById(String id) async {
    final row = await _dao.findById(id);
    return row?.toEntity();
  }

  /// Live badge figures: the server's last reconciled numbers, adjusted down by
  /// whatever the rep has done since that has not reached the server yet.
  ///
  /// ## Why not simply the lower of the two
  ///
  /// The obvious rule — take whichever of the local and server counts is
  /// smaller — is wrong in the case that matters most. On a fresh install, or
  /// after a spell offline, the local mirror holds fewer rows than the server
  /// knows about, so `min` reports **zero outstanding actions to a rep who has
  /// three**. The badge is silent precisely when there is most to say.
  ///
  /// ## What is actually subtracted
  ///
  /// The **outbox**, which is an exact record of the difference: every queued
  /// `read` is one notification the server still counts as unread, and every
  /// queued `action` is one outstanding item it still counts as open. So:
  ///
  ///     unread          = serverUnread         − queued reads
  ///     actionRequired  = serverActionRequired − queued actions
  ///
  /// A queued `read-all` clears the unread count outright, because that is what
  /// it will do server-side when it drains.
  ///
  /// This satisfies §7's "reconcile, never increment" — nothing is nudged, the
  /// server's figure is the base — while still moving the badge the instant the
  /// rep taps, which is what stops it feeling broken. Both directions are
  /// clamped at zero: the two sources are read at slightly different moments and
  /// a negative badge is never the right answer.
  ///
  /// Before the first reconcile there is no server figure at all, so the local
  /// mirror is all there is and is used directly.
  @override
  Stream<NotificationCounts> watchCounts() {
    return _dao.watchCountsSnapshot().map((snapshot) {
      if (snapshot.hasNoServerFigures) {
        return NotificationCounts(
          unread: snapshot.localUnread,
          actionRequired: snapshot.localActionRequired,
        );
      }

      final unread = snapshot.pendingReadAll > 0
          ? 0
          : _clamp((snapshot.serverUnread ?? 0) - snapshot.pendingReads);

      return NotificationCounts(
        unread: unread,
        actionRequired: _clamp(
          (snapshot.serverActionRequired ?? 0) - snapshot.pendingActions,
        ),
        byCategory: _decodeCategoryCounts(snapshot.byCategoryJson),
        syncTimestamp: snapshot.countsAt,
      );
    });
  }

  static int _clamp(int value) => value < 0 ? 0 : value;

  /// `{"ASSIGNMENT":2,"ORDER":7}` → a typed map.
  ///
  /// A malformed blob yields an empty map rather than throwing: this runs inside
  /// the badge stream, so an exception here would take the bell down app-wide
  /// over a cosmetic per-category figure.
  Map<NotificationCategory, int> _decodeCategoryCounts(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final counts = <NotificationCategory, int>{};
      for (final entry in decoded.entries) {
        final category = NotificationCategory.fromCode(entry.key.toString());
        final value = (entry.value as num?)?.toInt() ?? 0;
        counts[category] = (counts[category] ?? 0) + value;
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

  // ── Catch-up ────────────────────────────────────────────────────────

  @override
  ResultFuture<NotificationSyncResult> catchUp({bool full = false}) {
    return _inFlightCatchUp ??=
        _runCatchUp(full: full).whenComplete(() => _inFlightCatchUp = null);
  }

  Future<Result<NotificationSyncResult>> _runCatchUp({
    required bool full,
  }) async {
    // The gate `SessionManager` exists for: a guest has no inbox, and firing the
    // request anyway costs a round trip to be told 401 and puts an error banner
    // in front of somebody who did nothing wrong.
    if (!_session.canCallProtectedApi) {
      return const Success(NotificationSyncResult.notAttempted);
    }

    try {
      // Drain first. A queued acknowledgement that has not reached the server
      // yet means the server still thinks the item is unread — pulling before
      // draining would hand back that stale state, and although the DAO protects
      // pending rows from being overwritten, draining first keeps the mirror and
      // the server converging rather than fighting.
      await _drainQueue();

      final meta = await _dao.syncMeta();
      var cursor = full ? null : meta?.cursor;
      var page = ApiDefaults.firstPage;
      var received = 0;
      DateTime? newCursor;

      while (page <= ApiDefaults.notificationMaxCatchUpPages) {
        final result = await _remote.fetchPage(
          since: cursor,
          pageNumber: page,
          pageSize: ApiDefaults.notificationPageSize,
        );

        // Only advance the cursor on the last page. Storing page 1's timestamp
        // and then failing on page 2 would skip page 2 permanently — the next
        // run asks for changes after a point those rows already precede.
        newCursor = result.syncTimestamp ?? newCursor;

        await _dao.upsertPage(
          [for (final item in result.items) item.toRow()],
          cursor: result.hasMore ? null : newCursor,
        );

        received += result.items.length;
        if (!result.hasMore) break;
        page++;
      }

      if (page > ApiDefaults.notificationMaxCatchUpPages) {
        // Not silently truncated: a server that always reports `hasNextPage`, or
        // a cursor that never advances, is a defect and this is the only place it
        // is visible. The rows pulled so far are kept.
        _logger.warning('notifications.catchup_page_cap', fields: {
          'cap': ApiDefaults.notificationMaxCatchUpPages,
          'received': received,
        });
      }

      // Reconciled after the pull, so the badge reflects the rows just stored
      // rather than the state before them.
      await _reconcileCounts();

      _logger.info('notifications.catchup', fields: {
        'received': received,
        'pages': page,
        'full': full,
      });

      return Success(NotificationSyncResult(
        received: received,
        pages: page,
        cursor: newCursor,
      ));
    } on ApiException catch (e) {
      return Failed(_failureFor(e.error, 'notifications.catchup_failed'));
    } catch (error, stackTrace) {
      _logger.error('notifications.catchup_error',
          error: error, stackTrace: stackTrace);
      return const Failed(
          CacheFailure(message: 'Could not update your notifications.'));
    }
  }

  @override
  ResultFuture<NotificationCounts> refreshCounts() async {
    if (!_session.canCallProtectedApi) {
      return const Success(NotificationCounts.empty);
    }
    try {
      return Success(await _reconcileCounts());
    } on ApiException catch (e) {
      return Failed(_failureFor(e.error, 'notifications.counts_failed'));
    }
  }

  Future<NotificationCounts> _reconcileCounts() async {
    final counts = await _remote.fetchCounts();
    await _dao.writeCounts(
      unread: counts.unread,
      actionRequired: counts.actionRequired,
      byCategoryJson: _encodeCategoryCounts(counts),
      // The server's own `sync_timestamp` when it supplied one. Falling back to
      // the device clock is acceptable *here* and nowhere else: this value is
      // only ever read to label the counts as stale, never sent back as a
      // cursor, so a skewed clock costs a cosmetic timestamp rather than a
      // permanently broken sync (§6.1).
      at: counts.syncTimestamp ?? DateTime.now().toUtc(),
    );
    return counts;
  }

  /// `{"ASSIGNMENT": 2}` — the wire codes, not enum names, so the blob survives
  /// a value being inserted into the middle of the enum.
  String _encodeCategoryCounts(NotificationCounts counts) => jsonEncode({
        for (final entry in counts.byCategory.entries)
          entry.key.code: entry.value,
      });

  // ── Mutations ───────────────────────────────────────────────────────

  @override
  ResultFuture<void> markRead(String notificationId) async {
    final changed = await _dao.markRead(
      notificationId,
      Uuid.v4(),
      DateTime.now().toUtc(),
    );
    // Not an error. The item was already read — by this rep on another surface,
    // or by the catch-up that landed a moment ago. §8.1: the first read
    // timestamp wins, so there is nothing to do and nothing to report.
    if (!changed) return const Success(null);

    unawaited(_drainQueueQuietly());
    return const Success(null);
  }

  @override
  ResultFuture<int> markAllRead({String? categoryCode}) async {
    final cleared = await _dao.markAllRead(
      queueId: Uuid.v4(),
      at: DateTime.now().toUtc(),
      categoryCode: categoryCode,
    );
    if (cleared == 0) return const Success(0);
    unawaited(_drainQueueQuietly());
    return Success(cleared);
  }

  @override
  ResultFuture<void> recordAction(
    String notificationId, {
    String? actionId,
  }) async {
    final changed = await _dao.recordAction(
      notificationId,
      Uuid.v4(),
      DateTime.now().toUtc(),
      actionId: actionId,
    );
    if (!changed) {
      // The item is already closed — most often `resolved_elsewhere`, meaning
      // another approver decided first. Reported so the caller can say so
      // instead of leaving the button looking broken.
      return const Failed(ServerFailure(
        message: 'This has already been dealt with.',
        statusCode: 409,
      ));
    }

    unawaited(_drainQueueQuietly());
    return const Success(null);
  }

  @override
  ResultFuture<void> dismiss(String notificationId) async {
    final changed = await _dao.dismiss(
      notificationId,
      Uuid.v4(),
      DateTime.now().toUtc(),
    );
    if (!changed) {
      // Refused locally for the same reason the server answers 409: an item
      // awaiting acknowledgement cannot be swiped away (§5.4). Failing here
      // rather than in a round trip keeps the row from vanishing and reappearing.
      return const Failed(ServerFailure(
        message: 'This needs to be acknowledged before it can be cleared.',
        statusCode: 409,
      ));
    }
    unawaited(_drainQueueQuietly());
    return const Success(null);
  }

  @override
  ResultFuture<void> upsertFromPush(
    Map<String, String> data, {
    String? title,
    String? body,
  }) async {
    final push = PushMessage(data: data, title: title, body: body);
    final message = NotificationApiMapper.fromPush(
      push,
      receivedAt: DateTime.now().toUtc(),
    );

    // No notification id: the push cannot be reconciled against the inbox, so
    // the only correct response is a plain catch-up (§9.1).
    if (message == null) {
      unawaited(catchUp());
      return const Success(null);
    }

    // `partial: true` — the push withholds prices, credit limits, phone numbers
    // and the whole actions array (§9.2), so this row must not be mistaken for
    // the complete record. The DAO refuses to let it overwrite one.
    await _dao.upsertFromPush(message.toRow(partial: true));

    // The row the rep now sees is thin. The catch-up replaces it with the real
    // one, which is the difference between an actionable notification and a
    // heading with no buttons.
    unawaited(catchUp());
    return const Success(null);
  }

  // ── Queue drain ─────────────────────────────────────────────────────

  @override
  ResultFuture<List<String>> drainActionQueue() {
    return _inFlightDrain ??=
        _drainQueue().whenComplete(() => _inFlightDrain = null);
  }

  /// Drains the queue and returns the ids that came back
  /// `409 Notification.AlreadyResolved` — the ones a rep needs telling about,
  /// because somebody else decided while they were offline.
  Future<Result<List<String>>> _drainQueue() async {
    if (!_session.canCallProtectedApi) return const Success([]);

    final resolvedElsewhere = <String>[];
    final queued = await _dao.pendingActions();

    for (final row in queued) {
      final action = row.toEntity();
      try {
        await _send(action);
        await _dao.removeQueued(action.id);
      } on ApiException catch (e) {
        final outcome = _classify(e.error);
        switch (outcome) {
          case _DrainOutcome.resolved:
            // Somebody else got there first. Drop the row, correct the local
            // state, and hand the id back so the rep is told — §8.5 requires a
            // clear resolution message, never a silent discard. **Do not
            // retry**: the server's answer will not change.
            await _dao.removeQueued(action.id);
            if (action.notificationId.isNotEmpty) {
              await _dao.markResolvedElsewhere(action.notificationId);
              resolvedElsewhere.add(action.notificationId);
            }
            _logger.info('notifications.queue_resolved_elsewhere',
                fields: {'kind': action.kind.code});

          case _DrainOutcome.gone:
            // `404 Notification.NotFound` — not ours, or never existed. Remove
            // it from the local cache, as the error table directs.
            await _dao.removeQueued(action.id);
            if (action.notificationId.isNotEmpty) {
              await _dao.deleteById(action.notificationId);
            }

          case _DrainOutcome.transient:
            // Stop the whole drain and keep the queue. Continuing past a dead
            // connection would spend every remaining row against it and turn one
            // failure into a queue-wide retry storm on reconnect.
            await _dao.recordAttempt(action.id, action.attempts + 1);
            _logger.info('notifications.queue_deferred',
                fields: {'remaining': queued.length});
            return Success(resolvedElsewhere);

          case _DrainOutcome.permanent:
            // Replaying a request the server rejects on its merits will never
            // succeed, so the row goes. Logged at warning: an
            // `ActionNotOffered` here is a client bug worth seeing.
            await _dao.removeQueued(action.id);
            _logger.warning('notifications.queue_dropped', fields: {
              'kind': action.kind.code,
              'code': e.error.code,
            });
        }
      }
    }

    return Success(resolvedElsewhere);
  }

  /// Fire-and-forget drain used after a local mutation.
  ///
  /// Deliberately swallows its result: the mutation has already succeeded from
  /// the rep's point of view and the queue survives a failure. Errors still
  /// reach the log through [_drainQueue] itself.
  Future<void> _drainQueueQuietly() async {
    try {
      await drainActionQueue();
    } catch (error, stackTrace) {
      _logger.error('notifications.queue_drain_error',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _send(QueuedNotificationAction action) {
    return switch (action.kind) {
      NotificationMutationKind.read => _remote.markRead(action.notificationId),
      NotificationMutationKind.readAll =>
        _remote.markAllRead(categoryCode: action.category),
      NotificationMutationKind.action => _remote.recordAction(
          action.notificationId,
          actionId: action.actionId,
          occurredAt: action.occurredAt,
        ),
      NotificationMutationKind.dismiss =>
        _remote.dismiss(action.notificationId),
    };
  }

  // ── Lifecycle ───────────────────────────────────────────────────────

  @override
  Future<void> clear() => _dao.clearAll();

  /// Classifies a drain failure into the four behaviours §8.5 prescribes.
  ///
  /// Branches on `errorCode`, never on `detail` — §2: `detail` is English
  /// developer text, `errorCode` is the stable contract.
  _DrainOutcome _classify(ApiError error) {
    if (error.code == _alreadyResolved || error.statusCode == 409) {
      return _DrainOutcome.resolved;
    }
    if (error.code == _notFound || error.statusCode == 404) {
      return _DrainOutcome.gone;
    }
    // A 401 is transient by design: the interceptor refreshes and replays, and
    // if the refresh itself failed the session is expiring — either way the row
    // is worth keeping rather than discarding a rep's acknowledgement.
    if (error.code == ApiErrorCodes.network ||
        error.isUnauthenticated ||
        error.statusCode == 429 ||
        (error.statusCode ?? 0) >= 500) {
      return _DrainOutcome.transient;
    }
    return _DrainOutcome.permanent;
  }

  Failure _failureFor(ApiError error, String event) {
    _logger.warning(event, fields: {
      'code': error.code,
      'status': error.statusCode,
    });
    if (error.code == ApiErrorCodes.network) return const NetworkFailure();
    return ServerFailure(
      // The server localised this against the `Accept-Language` header the app
      // sends, so it is safe to show. `detail` never is.
      message: error.message ?? 'Could not reach your notifications.',
      statusCode: error.statusCode,
    );
  }

  /// §15. Actioned, dismissed, expired, or decided by somebody else.
  static const String _alreadyResolved = 'Notification.AlreadyResolved';

  /// §15. Not yours, or does not exist.
  static const String _notFound = 'Notification.NotFound';
}

/// What to do with a queued row that failed to send.
enum _DrainOutcome { resolved, gone, transient, permanent }
