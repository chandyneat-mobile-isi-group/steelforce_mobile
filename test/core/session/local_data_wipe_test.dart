import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/local_database_reset.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/features/order/data/local/sync_queue_local_data_source.dart';
import 'package:steelforce/features/order/data/session/quotation_unsent_work_source.dart';

const _logger = ConsoleAppLogger(verbose: false);

Future<int> _count(AppDatabase db, String table) async {
  final row =
      await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
  return row.data['c'] as int;
}

Future<void> _favorite(AppDatabase db, String depotId) => db.customInsert(
      'INSERT INTO depot_favorites (depot_id, created_at) VALUES (?, ?)',
      variables: [Variable(depotId), Variable(DateTime(2026))],
    );

Future<void> _queued(AppDatabase db, String id, String status) =>
    db.customInsert(
      'INSERT INTO sync_queue (id, quotation_id, status, created_at, updated_at) '
      "VALUES (?, ?, ?, '2026-01-01', '2026-01-01')",
      variables: [Variable(id), Variable('q-$id'), Variable(status)],
    );

class _FakeSource implements UnsentWorkSource {
  _FakeSource(this.unsent, {this.leftAfterSend = 0, this.throws = false});

  int unsent;
  final int leftAfterSend;
  final bool throws;
  int sends = 0;

  @override
  String get debugName => 'fake';

  @override
  Future<int> countUnsent() async {
    if (throws) throw StateError('unreadable');
    return unsent;
  }

  @override
  Future<int> countSendable() => countUnsent();

  @override
  Future<void> sendNow() async {
    sends++;
    unsent = leftAfterSend;
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('LocalDatabaseSessionStore', () {
    test('empties rep data but keeps the gazetteer and schema bookkeeping',
        () async {
      await _favorite(db, 'd1');
      await _queued(db, 's1', 'accepted');
      await db.customInsert(
        "INSERT INTO geo_provinces (code, name_en, name_km, unit) "
        "VALUES ('12', 'Phnom Penh', 'ភ្នំពេញ', 'Capital')",
      );
      await db.appMetadataDao.setValue('legacy.imported_at', '2026');
      await db.appMetadataDao
          .setValue(LocalDatabaseSessionStore.ownerKey, 'rep-a');

      await LocalDatabaseSessionStore(db).clearForSignOut();

      expect(await _count(db, 'depot_favorites'), 0);
      expect(await _count(db, 'sync_queue'), 0);
      expect(await _count(db, 'geo_provinces'), 1);
      expect(await db.appMetadataDao.getValue('legacy.imported_at'), '2026');
      expect(
          await db.appMetadataDao.getValue(LocalDatabaseSessionStore.ownerKey),
          isNull);
    });

    test('every table outside the kept set is wiped, including new ones',
        () async {
      // Wiping by exclusion is the point: a table added later must not need
      // anyone to remember this store.
      final wiped = db.allTables
          .map((t) => t.actualTableName)
          .where((n) => !LocalDatabaseSessionStore.keptTables.contains(n));
      expect(wiped, containsAll(['depots', 'products', 'visit_check_ins']));
      expect(
          LocalDatabaseSessionStore.keptTables, isNot(contains('sync_queue')));
    });
  });

  group('LocalDataOwnership', () {
    late SessionResetService reset;

    setUp(() =>
        reset = SessionResetService([LocalDatabaseSessionStore(db)], _logger));

    test('the first sign-in claims the data without wiping it', () async {
      await _favorite(db, 'd1');

      await LocalDataOwnership(db, reset).claim('rep-a');

      expect(await _count(db, 'depot_favorites'), 1);
      expect(
          await db.appMetadataDao.getValue(LocalDatabaseSessionStore.ownerKey),
          'rep-a');
    });

    test('the same rep signing back in keeps their data', () async {
      // An expired session: their unsent visits must still go out.
      final ownership = LocalDataOwnership(db, reset);
      await ownership.claim('rep-a');
      await _favorite(db, 'd1');

      await ownership.claim('rep-a');

      expect(await _count(db, 'depot_favorites'), 1);
    });

    test('a different rep signing in wipes the previous rep\'s data', () async {
      final ownership = LocalDataOwnership(db, reset);
      await ownership.claim('rep-a');
      await _favorite(db, 'd1');

      await ownership.claim('rep-b');

      expect(await _count(db, 'depot_favorites'), 0);
      expect(
          await db.appMetadataDao.getValue(LocalDatabaseSessionStore.ownerKey),
          'rep-b');
    });
  });

  group('UnsentWorkService', () {
    test('sums every source', () async {
      final service =
          UnsentWorkService([_FakeSource(2), _FakeSource(3)], _logger);
      expect(await service.count(), 5);
    });

    test('an unreadable source does not trap the rep in their session',
        () async {
      final service = UnsentWorkService(
          [_FakeSource(0, throws: true), _FakeSource(1)], _logger);
      expect(await service.count(), 1);
    });

    test('sendAll sends from every source and answers what is left', () async {
      final a = _FakeSource(2);
      final b = _FakeSource(4, leftAfterSend: 1);
      final service = UnsentWorkService([a, b], _logger);

      expect(await service.sendAll(), 1);
      expect(a.sends, 1);
      expect(b.sends, 1);
    });
  });

  test('QuotationUnsentWorkSource counts only what the server lacks', () async {
    for (final (i, status) in [
      'pendingSync',
      'syncing',
      'submitted',
      'failed',
      'conflict',
      'accepted',
      'rejected',
      'returned',
    ].indexed) {
      await _queued(db, 's$i', status);
    }
    var sent = 0;
    final source = QuotationUnsentWorkSource(
      SyncQueueLocalDataSourceImpl(db.syncQueueDao),
      send: () async => sent++,
    );

    expect(await source.countUnsent(), 5);
    await source.sendNow();
    expect(sent, 1);
  });
}
