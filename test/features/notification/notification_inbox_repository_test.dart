import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/data/repositories/notification_inbox_repository_impl.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// A remote source whose every call can be scripted to throw a chosen
/// `ApiError`.
///
/// Hand-written rather than mocked because the interesting assertions are about
/// *sequence* — which rows were sent, in what order, and what the queue looked
/// like afterwards — and a recording fake states that far more legibly than a
/// stack of `verify` calls.
class _FakeRemote implements NotificationRemoteDataSource {
  final List<String> calls = [];
  final List<NotificationMessage> page = [];

  DateTime? syncTimestamp = DateTime.utc(2026, 8, 25, 8, 12, 4);
  NotificationCounts counts = const NotificationCounts(unread: 1);

  /// Keyed by `kind:notificationId`, or `kind:` for a bulk call.
  final Map<String, ApiError> failures = {};

  /// Fails every mutation with a transport error.
  ///
  /// A flag rather than a scripted failure per call, because every local
  /// mutation fires a drain **without awaiting it** — exactly as production
  /// does — so a test that adds and removes a single scripted failure races that
  /// drain and passes or fails on timing. Flipping one switch is unambiguous.
  bool offline = false;

  void _maybeThrow(String key) {
    if (offline) {
      throw const ApiException(ApiError(code: ApiErrorCodes.network));
    }
    final error = failures[key];
    if (error != null) throw ApiException(error);
  }

  @override
  Future<NotificationPage> fetchPage({
    DateTime? since,
    int pageNumber = 1,
    int pageSize = 100,
  }) async {
    calls.add('fetchPage:${since?.toIso8601String() ?? 'null'}');
    // Deliberately not gated by [offline]: the tests below queue mutations while
    // the mutation endpoints fail, then assert on what the catch-up did. Making
    // the read fail too would only test the fake.
    final error = failures['fetchPage:'];
    if (error != null) throw ApiException(error);
    return NotificationPage(
      items: pageNumber == 1 ? List.of(page) : const [],
      hasMore: false,
      syncTimestamp: syncTimestamp,
    );
  }

  @override
  Future<NotificationCounts> fetchCounts() async {
    calls.add('fetchCounts:');
    final error = failures['fetchCounts:'];
    if (error != null) throw ApiException(error);
    return counts;
  }

  @override
  Future<void> markRead(String id) async {
    calls.add('read:$id');
    _maybeThrow('read:$id');
  }

  @override
  Future<int> markAllRead({String? categoryCode}) async {
    calls.add('read_all:${categoryCode ?? ''}');
    _maybeThrow('read_all:');
    return 1;
  }

  @override
  Future<void> recordAction(String id,
      {String? actionId, DateTime? occurredAt}) async {
    calls.add('action:$id');
    _maybeThrow('action:$id');
  }

  @override
  Future<void> dismiss(String id) async {
    calls.add('dismiss:$id');
    _maybeThrow('dismiss:$id');
  }

  @override
  Future<void> invokeAction({
    required String endpoint,
    required String method,
  }) async {
    calls.add('invoke:$method $endpoint');
    _maybeThrow('invoke:');
  }

  @override
  Future<PushRegistrationResult> registerDevice(
          PushRegistration registration) async =>
      throw UnimplementedError();

  @override
  Future<void> deregisterDevice(String deviceId) async =>
      throw UnimplementedError();

  @override
  Future<NotificationPreferences> fetchPreferences() async =>
      throw UnimplementedError();

  @override
  Future<NotificationPreferences> savePreferences(
          NotificationPreferences preferences) async =>
      throw UnimplementedError();
}

NotificationMessage _message(
  String id, {
  bool requiresAck = false,
  NotificationState state = NotificationState.unread,
}) =>
    NotificationMessage(
      id: id,
      eventCode: 'ROUTE.ASSIGNED',
      category: NotificationCategory.assignment,
      priority: NotificationPriority.p2,
      title: 'Title $id',
      body: 'Body $id',
      requiresAck: requiresAck,
      state: state,
      createdAt: DateTime.utc(2026, 8, 25, 8),
    );

/// Lets the fire-and-forget drain that follows every local mutation finish.
///
/// The repository deliberately does not await it — a rep's acknowledgement must
/// not wait on the network — so a test that asserts on the queue immediately
/// afterwards is asserting on a race.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late SessionManager session;
  late NotificationInboxRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = _FakeRemote();
    session = SessionManager()
      ..setUser(const User(
        id: 'u1',
        fullName: 'Dara',
        email: 'dara@example.com',
        roles: {UserRole.salesRep},
      ));
    repository = NotificationInboxRepositoryImpl(
      dao: db.notificationDao,
      remote: remote,
      session: session,
      logger: const ConsoleAppLogger(verbose: false),
    );
  });

  tearDown(() async {
    session.dispose();
    await db.close();
  });

  group('catch-up (§6.1)', () {
    test('stores the page and the server-issued cursor', () async {
      remote.page.addAll([_message('n1'), _message('n2')]);

      final result = await repository.catchUp();

      expect(result.when(success: (r) => r.received, failure: (_) => -1), 2);
      expect((await db.notificationDao.syncMeta())!.syncTimestamp,
          DateTime.utc(2026, 8, 25, 8, 12, 4));
    });

    test('sends the stored cursor back as `since`, never a device clock',
        () async {
      // §6.1's headline failure: a handset ten minutes fast that sends its own
      // clock asks for "changes since the future", receives nothing for ever,
      // and reports no error.
      remote.page.add(_message('n1'));
      await repository.catchUp();
      remote.calls.clear();

      await repository.catchUp();

      expect(
        remote.calls,
        contains('fetchPage:2026-08-25T08:12:04.000Z'),
      );
    });

    test('full: true discards the cursor and re-pulls from the start',
        () async {
      remote.page.add(_message('n1'));
      await repository.catchUp();
      remote.calls.clear();

      await repository.catchUp(full: true);

      expect(remote.calls, contains('fetchPage:null'));
    });

    test('a guest does not fire the request at all', () async {
      session.clear();

      final result = await repository.catchUp();

      expect(remote.calls, isEmpty);
      expect(result.when(success: (r) => r.skipped, failure: (_) => false),
          isTrue);
    });

    test('drains the queue before pulling', () async {
      // A queued acknowledgement that has not reached the server means the
      // server still thinks the item is unread. Pushing first keeps the two
      // converging rather than fighting.
      remote.page.add(_message('n1', requiresAck: true));
      await repository.catchUp();
      await repository.recordAction('n1', actionId: 'ack');
      remote.calls.clear();

      await repository.catchUp();

      expect(remote.calls.indexOf('action:n1'),
          lessThan(remote.calls.indexOf('fetchPage:2026-08-25T08:12:04.000Z')));
    });

    test('a network failure leaves the cursor where it was', () async {
      remote.page.add(_message('n1'));
      await repository.catchUp();
      remote.failures['fetchPage:'] =
          const ApiError(code: ApiErrorCodes.network);

      final result = await repository.catchUp();

      expect(result.when(success: (_) => false, failure: (_) => true), isTrue);
      expect((await db.notificationDao.syncMeta())!.syncTimestamp,
          DateTime.utc(2026, 8, 25, 8, 12, 4));
    });
  });

  group('local-first mutations', () {
    test('mark read succeeds offline and keeps the call queued', () async {
      remote.page.add(_message('n1'));
      await repository.catchUp();
      remote.offline = true;

      final result = await repository.markRead('n1');
      await _settle();

      // The rep sees it as read. Reporting a failure here would have them tap
      // again, which is how one route gets acknowledged twice.
      expect(result.when(success: (_) => true, failure: (_) => false), isTrue);
      expect((await db.notificationDao.findById('n1'))!.state, 'read');
      expect(await db.notificationDao.pendingActions(), hasLength(1));
    });

    test('dismissing an item that needs acknowledgement fails locally',
        () async {
      // Matches the server's 409 without spending a round trip to learn it, and
      // stops the row vanishing and springing back.
      remote.page.add(_message('n1', requiresAck: true));
      await repository.catchUp();

      final result = await repository.dismiss('n1');

      expect(result.when(success: (_) => false, failure: (f) => f.statusCode),
          409);
      expect(remote.calls, isNot(contains('dismiss:n1')));
    });

    test('acting on an already-resolved item reports the conflict', () async {
      remote.page
          .add(_message('n1', state: NotificationState.resolvedElsewhere));
      await repository.catchUp();

      final result = await repository.recordAction('n1');

      expect(result.when(success: (_) => false, failure: (f) => f.statusCode),
          409);
    });
  });

  group('queue drain (§8.5)', () {
    /// Stores [id], reads it while offline, and lets the fire-and-forget drain
    /// settle — leaving exactly one queued `read` and a reachable server.
    Future<void> queueRead(String id) async {
      remote.page.add(_message(id));
      await repository.catchUp();
      remote.offline = true;
      await repository.markRead(id);
      await _settle();
      remote.offline = false;
      remote.calls.clear();
    }

    test('a 409 drops the row, corrects the state and reports the id',
        () async {
      await queueRead('n1');
      remote.failures['read:n1'] = const ApiError(
        code: 'Notification.AlreadyResolved',
        statusCode: 409,
      );

      final result = await repository.drainActionQueue();

      // §8.3: refresh, tell the rep, **do not retry**.
      expect(result.when(success: (ids) => ids, failure: (_) => <String>[]),
          ['n1']);
      expect(await db.notificationDao.pendingActions(), isEmpty);
      expect((await db.notificationDao.findById('n1'))!.state,
          'resolved_elsewhere');
    });

    test('a transient failure keeps the whole queue for the next reconnect',
        () async {
      // Both queued inside one offline window. Queueing them separately would
      // let the catch-up between them drain the first, which is correct
      // behaviour but leaves nothing to assert.
      remote.page.addAll([_message('n1'), _message('n2')]);
      await repository.catchUp();
      remote.offline = true;
      await repository.markRead('n1');
      await repository.markRead('n2');
      await _settle();

      await repository.drainActionQueue();

      // Both survive: continuing past a dead connection would spend every
      // remaining row against it.
      expect(await db.notificationDao.pendingActions(), hasLength(2));
    });

    test('a 404 drops the queue row and the local notification', () async {
      // §15: not yours, or does not exist — remove it from the local cache.
      await queueRead('n1');
      remote.failures['read:n1'] = const ApiError(
        code: 'Notification.NotFound',
        statusCode: 404,
      );

      await repository.drainActionQueue();

      expect(await db.notificationDao.pendingActions(), isEmpty);
      expect(await db.notificationDao.findById('n1'), isNull);
    });

    test('a permanent client error drops the row rather than looping',
        () async {
      await queueRead('n1');
      remote.failures['read:n1'] = const ApiError(
        code: 'Notification.ActionNotOffered',
        statusCode: 400,
      );

      await repository.drainActionQueue();

      expect(await db.notificationDao.pendingActions(), isEmpty);
    });

    test('a successful replay clears the queue', () async {
      await queueRead('n1');

      await repository.drainActionQueue();

      expect(await db.notificationDao.pendingActions(), isEmpty);
      expect(remote.calls, contains('read:n1'));
    });

    test('replays in the order the rep performed them', () async {
      // A read captured before an action on the same item must replay in that
      // order, or the server records a read timestamp *after* the action and the
      // time-to-open metric reads as negative.
      remote.page.add(_message('n1', requiresAck: true));
      await repository.catchUp();

      remote.offline = true;
      await repository.markRead('n1');
      await repository.recordAction('n1', actionId: 'ack');
      await _settle();
      remote.offline = false;
      remote.calls.clear();

      await repository.drainActionQueue();

      expect(remote.calls.indexOf('read:n1'),
          lessThan(remote.calls.indexOf('action:n1')));
    });
  });

  group('counts (§7)', () {
    test('reports the server figures even with an empty local mirror',
        () async {
      // The regression this rule exists for: a fresh install has no rows, so a
      // "lower of the two" rule would report zero outstanding actions to a rep
      // who has three — the badge silent exactly when there is most to say.
      remote.counts = const NotificationCounts(unread: 12, actionRequired: 3);

      await repository.refreshCounts();

      final counts = await repository.watchCounts().first;
      expect(counts.unread, 12);
      expect(counts.actionRequired, 3);
    });

    test('an undrained read is subtracted from the server figure', () async {
      remote.page.addAll([_message('n1'), _message('n2')]);
      await repository.catchUp();
      remote.counts = const NotificationCounts(unread: 5);
      await repository.refreshCounts();

      remote.offline = true;
      await repository.markRead('n1');
      await _settle();

      // 5 the server knows about, minus the one read that has not reached it.
      // The badge moves the instant the rep taps without inventing a number.
      expect((await repository.watchCounts().first).unread, 4);
    });

    test('an undrained acknowledgement is subtracted too', () async {
      remote.page.add(_message('n1', requiresAck: true));
      await repository.catchUp();
      remote.counts = const NotificationCounts(unread: 1, actionRequired: 2);
      await repository.refreshCounts();

      remote.offline = true;
      await repository.recordAction('n1', actionId: 'ack');
      await _settle();

      expect((await repository.watchCounts().first).actionRequired, 1);
    });

    test('a queued read-all clears the unread badge outright', () async {
      remote.page.add(_message('n1'));
      await repository.catchUp();
      remote.counts = const NotificationCounts(unread: 9);
      await repository.refreshCounts();

      remote.offline = true;
      await repository.markAllRead();
      await _settle();

      expect((await repository.watchCounts().first).unread, 0);
    });

    test('a drained read leaves the server figure alone until the reconcile',
        () async {
      remote.page.add(_message('n1'));
      await repository.catchUp();
      remote.counts = const NotificationCounts(unread: 5);
      await repository.refreshCounts();

      // Drains successfully, so the outbox is empty and there is nothing left to
      // subtract — the next reconcile is what moves the number.
      await repository.markRead('n1');
      await _settle();

      expect((await repository.watchCounts().first).unread, 5);
    });

    test('before the first reconcile the local mirror is used', () async {
      remote.page.addAll([_message('n1'), _message('n2', requiresAck: true)]);
      // A catch-up reconciles, so store rows without one.
      await repository.upsertFromPush(const {
        'notification_id': 'p1',
        'category': 'SYSTEM',
      }, title: 'Hi', body: 'There');
      await _settle();

      final counts = await repository.watchCounts().first;
      expect(counts.unread, greaterThan(0));
    });
  });

  group('push ingestion (§9.2)', () {
    test('a push with no id triggers a catch-up and stores nothing', () async {
      await repository.upsertFromPush(const {'category': 'SYSTEM'});
      // The catch-up is fired without awaiting, so let it settle.
      await Future<void>.delayed(Duration.zero);

      expect(remote.calls.where((c) => c.startsWith('fetchPage')), isNotEmpty);
    });

    test('a push row is stored partial and then completed by the catch-up',
        () async {
      remote.page.add(_message('n1', requiresAck: true));

      await repository.upsertFromPush(
        const {'notification_id': 'n1', 'category': 'ASSIGNMENT'},
        title: 'New route assigned',
        body: 'Tap to review.',
      );
      // The push row lands first, thin.
      expect((await db.notificationDao.findById('n1'))!.partial, isTrue);

      await repository.catchUp();

      final row = await db.notificationDao.findById('n1');
      expect(row!.partial, isFalse);
      expect(row.requiresAck, isTrue,
          reason: 'the full record carries what the push withheld');
    });
  });

  test('watch returns the inbox slice for a query', () async {
    remote.page.addAll([
      _message('n1', requiresAck: true),
      _message('n2'),
    ]);
    await repository.catchUp();

    final actionNeeded = await repository
        .watch(const NotificationQuery(scope: NotificationScope.actionNeeded))
        .first;

    expect(actionNeeded.map((n) => n.id), ['n1']);
  });

  test('clear drops everything on sign-out', () async {
    remote.page.add(_message('n1'));
    await repository.catchUp();

    await repository.clear();

    expect(await repository.watch(const NotificationQuery()).first, isEmpty);
    expect(await db.notificationDao.syncMeta(), isNull);
  });
}
