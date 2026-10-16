import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/notification_dao.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';

/// `NotificationDao` against an in-memory database.
///
/// The tests below are chosen for the failures that would be **invisible in
/// production**: a state change with no queued call (the supervisor's escalation
/// fires against a rep who did the work), a catch-up overwriting an
/// acknowledgement that has not drained yet (the item reappears in Action
/// needed), and a cursor advancing past rows that were never stored (a
/// permanently blank inbox with no error anywhere).
NotificationRow _row(
  String id, {
  String state = 'unread',
  bool requiresAck = false,
  String category = 'ASSIGNMENT',
  bool partial = false,
  int? badge,
  DateTime? createdAt,
}) {
  return NotificationRow(
    id: id,
    eventCode: 'ROUTE.ASSIGNED',
    category: category,
    priority: 'P2',
    title: 'Title $id',
    body: 'Body $id',
    requiresAck: requiresAck,
    state: state,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 25, 8),
    badge: badge,
    partial: partial,
  );
}

void main() {
  late AppDatabase db;
  late NotificationDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.notificationDao;
  });
  tearDown(() => db.close());

  final at = DateTime.utc(2026, 8, 25, 9);

  group('state changes enqueue in the same transaction (ADR-006)', () {
    test('markRead writes the mirror and queues one call', () async {
      await dao.upsertPage([_row('n1')]);

      expect(await dao.markRead('n1', 'q1', at), isTrue);

      expect((await dao.findById('n1'))!.state, 'read');
      final queued = await dao.pendingActions();
      expect(queued, hasLength(1));
      expect(queued.single.kind, 'read');
      expect(queued.single.notificationId, 'n1');
    });

    test('markRead on an already-read row queues nothing', () async {
      // §8.1: the first read timestamp wins, because that is what the
      // time-to-open metric measures. A second queued read would replace it.
      await dao.upsertPage([_row('n1', state: 'read')]);

      expect(await dao.markRead('n1', 'q1', at), isFalse);
      expect(await dao.pendingActions(), isEmpty);
    });

    test('recordAction closes the row and queues the action id', () async {
      await dao.upsertPage([_row('n1', requiresAck: true)]);

      expect(
        await dao.recordAction('n1', 'q1', at, actionId: 'ack'),
        isTrue,
      );

      final row = await dao.findById('n1');
      expect(row!.state, 'actioned');
      expect(row.actionedAt, isNotNull);
      // Acting implies reading: the row must not be left looking unopened.
      expect(row.readAt, isNotNull);

      final queued = await dao.pendingActions();
      expect(queued.single.kind, 'action');
      expect(queued.single.actionId, 'ack');
    });

    test('recordAction refuses a row somebody else already resolved', () async {
      await dao.upsertPage([_row('n1', state: 'resolved_elsewhere')]);

      expect(await dao.recordAction('n1', 'q1', at), isFalse);
      expect((await dao.findById('n1'))!.state, 'resolved_elsewhere');
      expect(await dao.pendingActions(), isEmpty);
    });

    test('dismiss refuses an item that requires acknowledgement', () async {
      // Matches the server's 409 (§5.4), so the row never vanishes and springs
      // back.
      await dao.upsertPage([_row('n1', requiresAck: true)]);

      expect(await dao.dismiss('n1', 'q1', at), isFalse);
      expect((await dao.findById('n1'))!.state, 'unread');
      expect(await dao.pendingActions(), isEmpty);
    });

    test('markAllRead queues one bulk call, not one per row', () async {
      await dao.upsertPage([_row('n1'), _row('n2'), _row('n3')]);

      expect(await dao.markAllRead(queueId: 'q1', at: at), 3);

      final queued = await dao.pendingActions();
      expect(queued, hasLength(1));
      expect(queued.single.kind, 'read_all');
      expect(queued.single.notificationId, isEmpty);
    });

    test('markAllRead scoped to a category leaves the others unread', () async {
      // §8.2: the button clears what the rep can see, not what they cannot.
      await dao.upsertPage([
        _row('n1', category: 'ORDER'),
        _row('n2', category: 'ASSIGNMENT'),
      ]);

      expect(
        await dao.markAllRead(queueId: 'q1', at: at, categoryCode: 'ORDER'),
        1,
      );

      expect((await dao.findById('n1'))!.state, 'read');
      expect((await dao.findById('n2'))!.state, 'unread');
      expect((await dao.pendingActions()).single.category, 'ORDER');
    });

    test('markAllRead with nothing unread queues no request', () async {
      await dao.upsertPage([_row('n1', state: 'read')]);

      expect(await dao.markAllRead(queueId: 'q1', at: at), 0);
      expect(await dao.pendingActions(), isEmpty);
    });
  });

  group('catch-up must not undo work that has not drained', () {
    test('a pending row keeps its local state but takes fresh content',
        () async {
      await dao.upsertPage([_row('n1', requiresAck: true)]);
      await dao.recordAction('n1', 'q1', at, actionId: 'ack');

      // The server has not seen the acknowledgement yet, so its copy still says
      // unread. Without the guard this would put the item straight back into the
      // rep's Action needed tab — visibly undoing work they had done.
      await dao.upsertPage([
        NotificationRow(
          id: 'n1',
          eventCode: 'ROUTE.ASSIGNED',
          category: 'ASSIGNMENT',
          priority: 'P1',
          title: 'Corrected title',
          body: 'Corrected body',
          requiresAck: true,
          state: 'unread',
          createdAt: DateTime.utc(2026, 8, 25, 8),
          partial: false,
        ),
      ]);

      final row = await dao.findById('n1');
      expect(row!.state, 'actioned', reason: 'local state must survive');
      expect(row.title, 'Corrected title',
          reason: 'everything except the lifecycle should still refresh');
      expect(row.priority, 'P1');
    });

    test('a row with no queued change is overwritten wholesale', () async {
      await dao.upsertPage([_row('n1', state: 'read')]);
      await dao.upsertPage([_row('n1', state: 'expired')]);

      expect((await dao.findById('n1'))!.state, 'expired');
    });
  });

  group('cursor', () {
    test('advances only when a page is written with it', () async {
      final cursor = DateTime.utc(2026, 8, 25, 8, 12, 4);
      await dao.upsertPage([_row('n1')], cursor: cursor);

      expect((await dao.syncMeta())!.syncTimestamp, cursor);
    });

    test('is left untouched when a page carries none', () async {
      final cursor = DateTime.utc(2026, 8, 25, 8, 12, 4);
      await dao.upsertPage([_row('n1')], cursor: cursor);
      // Mid-run page: the cursor is withheld until the last page lands, so a
      // crash between pages cannot skip the rows in between.
      await dao.upsertPage([_row('n2')]);

      expect((await dao.syncMeta())!.syncTimestamp, cursor);
    });

    test('advancing the cursor does not blank the reconciled counts', () async {
      await dao.writeCounts(
        unread: 12,
        actionRequired: 3,
        byCategoryJson: '{"ORDER":7}',
        at: DateTime.utc(2026, 8, 25),
      );
      await dao.upsertPage([_row('n1')], cursor: DateTime.utc(2026, 8, 25, 9));

      final meta = await dao.syncMeta();
      expect(meta!.unread, 12,
          reason: 'a blanked badge is a badge nobody trusts');
      expect(meta.actionRequired, 3);
      expect(meta.byCategoryJson, '{"ORDER":7}');
    });
  });

  group('push ingestion', () {
    test('a partial push row does not overwrite the full record', () async {
      await dao.upsertPage([_row('n1', state: 'read')]);

      await dao.upsertFromPush(_row('n1', partial: true, state: 'unread'));

      final row = await dao.findById('n1');
      expect(row!.state, 'read');
      expect(row.partial, isFalse);
    });

    test('a push refreshes the badge snapshot on a full record', () async {
      await dao.upsertPage([_row('n1', badge: 1)]);
      await dao.upsertFromPush(_row('n1', partial: true, badge: 5));

      expect((await dao.findById('n1'))!.badge, 5);
    });

    test('a push for an unseen notification is stored as partial', () async {
      await dao.upsertFromPush(_row('n1', partial: true));

      final row = await dao.findById('n1');
      expect(row!.partial, isTrue,
          reason: 'a push carries no actions (§9.2) and must say so');
    });
  });

  group('ordering and filters', () {
    test('outstanding actions pin above newer ordinary items', () async {
      await dao.upsertPage([
        _row('old-ack',
            requiresAck: true, createdAt: DateTime.utc(2026, 8, 20)),
        _row('new-plain', createdAt: DateTime.utc(2026, 8, 25)),
      ]);

      final rows = await dao.watchInbox(
        states: const {'unread', 'read'},
      ).first;

      expect(rows.map((r) => r.id), ['old-ack', 'new-plain']);
    });

    test('the action-needed scope excludes items that need nothing', () async {
      await dao.upsertPage([
        _row('n1', requiresAck: true),
        _row('n2'),
      ]);

      final rows = await dao.watchInbox(
        states: const {'unread', 'read'},
        requiresAckOnly: true,
      ).first;

      expect(rows.map((r) => r.id), ['n1']);
    });

    test('a read item that still needs acknowledgement stays outstanding',
        () async {
      // §8.3: reading is not acting. This is the assertion that protects the
      // whole escalation chain.
      await dao.upsertPage([_row('n1', requiresAck: true)]);
      await dao.markRead('n1', 'q1', at);

      final rows = await dao.watchInbox(
        states: const {'unread', 'read'},
        requiresAckOnly: true,
      ).first;

      expect(rows.map((r) => r.id), ['n1']);
      expect((await dao.localCounts()).actionRequired, 1);
    });
  });

  group('sign-out', () {
    test('clearAll drops rows, queue and cursor together', () async {
      await dao.upsertPage([_row('n1')], cursor: DateTime.utc(2026, 8, 25));
      await dao.markRead('n1', 'q1', at);

      await dao.clearAll();

      expect(await dao.findById('n1'), isNull);
      expect(await dao.pendingActions(), isEmpty);
      // A cursor outliving its rows asks for "changes since" a point whose rows
      // are gone, and leaves a permanently blank inbox with no error.
      expect(await dao.syncMeta(), isNull);
    });
  });

  test('the DAO closed-state list matches the domain enum', () {
    // The DAO cannot import the domain enum (inward dependencies only,
    // `docs/blueprint/system-architecture.md` §2), so it keeps its own copy of the four closed
    // states. This is what stops the two drifting apart silently — the symptom
    // otherwise is a dismissed notification quietly becoming actionable again.
    final fromDomain = NotificationState.values
        .where((s) => s.isClosed)
        .map((s) => s.code)
        .toSet();

    expect(NotificationDao.closedStates, fromDomain);
  });

  test('a queued row records its attempt count', () async {
    await dao.upsertPage([_row('n1')]);
    await dao.markRead('n1', 'q1', at);

    await dao.recordAttempt('q1', 2);

    expect((await dao.pendingActions()).single.attempts, 2);
  });

  test('markResolvedElsewhere corrects state without queueing', () async {
    // §8.3: refresh, tell the rep, **do not retry**.
    await dao.upsertPage([_row('n1')]);

    await dao.markResolvedElsewhere('n1');

    expect((await dao.findById('n1'))!.state, 'resolved_elsewhere');
    expect(await dao.pendingActions(), isEmpty);
  });

  test('writeCounts replaces rather than accumulates', () async {
    final at1 = DateTime.utc(2026, 8, 25, 8);
    await dao.writeCounts(
        unread: 5, actionRequired: 2, byCategoryJson: '{}', at: at1);
    await dao.writeCounts(
        unread: 1, actionRequired: 0, byCategoryJson: '{}', at: at1);

    final meta = await dao.syncMeta();
    expect(meta!.unread, 1);
    expect(meta.actionRequired, 0);
  });

  test('localCounts derives from rows, not from a stored counter', () async {
    await dao.upsertPage([
      _row('n1'),
      _row('n2', state: 'read'),
      _row('n3', requiresAck: true),
      _row('n4', state: 'dismissed'),
    ]);

    final counts = await dao.localCounts();
    expect(counts.unread, 2, reason: 'n1 and n3');
    expect(counts.actionRequired, 1, reason: 'n3 only');
  });

  // A guard on the ADR-011 decision, matching `foreign_key_schema_test.dart`'s
  // reasoning. A push can land before the catch-up page carrying its
  // notification, so a queue row legitimately references a row this device has
  // not stored yet. A foreign key here would abort that write and lose the
  // rep's acknowledgement rather than harmlessly orphaning a row.
  test('the outbox has no foreign key onto notifications', () async {
    final keys = await db
        .customSelect("PRAGMA foreign_key_list('notification_action_queue');")
        .get();

    expect(keys, isEmpty);
  });

  test('a queue row survives a notification the device has never seen',
      () async {
    // The same guarantee, exercised end to end rather than read off a pragma.
    await db.into(db.notificationActionQueue).insert(
          NotificationActionQueueCompanion.insert(
            id: 'q1',
            notificationId: 'never-synced',
            kind: 'read',
            occurredAt: at,
            actionId: const Value(null),
          ),
        );

    expect((await dao.pendingActions()).single.notificationId, 'never-synced');
  });
}
