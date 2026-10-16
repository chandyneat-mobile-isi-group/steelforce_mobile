import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_push_summary.dart';

/// A rep works four or five stops with no signal, then comes back online.
///
/// What the server must see, per stop: check-in, then the orders taken there,
/// then check-out — and the stops in the order they were walked.
class _Network implements NetworkInfo {
  bool online = true;
  @override
  Future<bool> get isConnected async => online;
}

/// Records every request and, by default, accepts every row.
class _Remote implements VisitSyncRemoteDataSource {
  _Remote(this.log);
  final List<String> log;
  final Set<String> refuseOnce = {};

  @override
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch) async {
    log.add([
      if (batch.checkIns.isNotEmpty)
        'checkIns:${batch.checkIns.map((r) => r.id).join(',')}',
      if (batch.checkOuts.isNotEmpty)
        'checkOuts:${batch.checkOuts.map((r) => r.id).join(',')}',
      if (batch.orderLines.isNotEmpty)
        'lines:${batch.orderLines.map((r) => r.id).join(',')}',
    ].join(' '));
    final ids = batch.idsByTable().values.expand((ids) => ids).toList();
    final refused = ids.where(refuseOnce.contains).toList();
    refuseOnce.removeAll(refused);
    return VisitPushResult(
      acceptedIds: ids.where((id) => !refused.contains(id)).toList(),
      rejectedIds: refused,
      syncedAt: DateTime.utc(2026, 10, 5, 18),
    );
  }
}

void main() {
  late AppDatabase db;
  late VisitDriftLocalDataSource local;
  late _Network network;
  late List<String> log;
  late _Remote remote;
  late VisitSyncRepositoryImpl sync;

  const logger = ConsoleAppLogger(verbose: false);
  final morning = DateTime.utc(2026, 10, 5, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = VisitDriftLocalDataSource(db.visitDao, logger);
    network = _Network();
    log = [];
    remote = _Remote(log);
    sync = VisitSyncRepositoryImpl(
      remote: remote,
      local: local,
      network: network,
      logger: logger,
      // Stands in for the quotations queue.
      sendBeforeCaptures: () async => log.add('orders'),
    );
  });

  tearDown(() => db.close());

  CheckInRecordModel checkIn(int stop) => CheckInRecordModel(
        id: 'ci-$stop',
        stopId: 's-$stop',
        timestamp: morning.add(Duration(hours: stop)),
        latitude: 11.55,
        longitude: 104.91,
        accuracyMeters: 8,
        distanceFromDepotMeters: 20,
        isMocked: false,
      );

  CheckOutRecordModel checkOut(int stop) => CheckOutRecordModel(
        id: 'co-$stop',
        stopId: 's-$stop',
        timestamp: morning.add(Duration(hours: stop, minutes: 40)),
        latitude: 11.55,
        longitude: 104.91,
        durationMinutes: 40,
        visitSummary: 'Visit completed',
      );

  VisitOrderLineModel line(int stop) => VisitOrderLineModel(
        id: 'ol-$stop',
        stopId: 's-$stop',
        productId: 'P-$stop',
        productName: 'Rebar',
        quantity: 10,
        unit: 'pcs',
        unitPrice: 4.5,
      );

  /// Five stops worked offline, saved out of order on purpose — the device
  /// must not rely on insertion order.
  Future<void> workFiveStopsOffline() async {
    for (final stop in [3, 1, 5, 2, 4]) {
      await local.insertCheckIn(checkIn(stop));
      await local.insertOrderLine(line(stop));
      await local.insertCheckOut(checkOut(stop));
    }
  }

  test('offline, every check-in and check-out stays on the device', () async {
    network.online = false;
    await workFiveStopsOffline();

    final result = await sync.pushPendingVisitData();

    expect(result, isA<Failed<VisitPushSummary>>());
    expect((result as Failed).failure, isA<NetworkFailure>());
    expect(log, isEmpty, reason: 'no request, and orders not touched');
    expect(await local.countPendingVisitRecords(), 15);
    expect(await local.countPendingCheckIns(), 5);
  });

  test(
      'back online, five stops go out as check-ins, then orders, then '
      'check-outs, each in the order the stops were walked', () async {
    await workFiveStopsOffline();

    final result = await sync.pushPendingVisitData();

    expect(log, [
      'checkIns:ci-1,ci-2,ci-3,ci-4,ci-5',
      'orders',
      'checkOuts:co-1,co-2,co-3,co-4,co-5 lines:ol-3,ol-1,ol-5,ol-2,ol-4',
    ]);
    expect((result as Success<VisitPushSummary>).data.pushedCount, 15);
    expect(await local.countPendingVisitRecords(), 0);
  });

  test(
      'a check-in the server refuses for now holds back that stop only; '
      'its check-out follows it on the next push', () async {
    await workFiveStopsOffline();
    remote.refuseOnce.add('ci-3');

    await sync.pushPendingVisitData();

    expect(log.last, 'checkOuts:co-1,co-2,co-4,co-5 lines:ol-1,ol-5,ol-2,ol-4');
    expect(await local.countPendingCheckIns(), 1);
    expect(await local.countPendingVisitRecords(), 3,
        reason: 'ci-3, ol-3 and co-3 are still on the device');

    log.clear();
    await sync.pushPendingVisitData();

    expect(log, ['checkIns:ci-3', 'orders', 'checkOuts:co-3 lines:ol-3']);
    expect(await local.countPendingVisitRecords(), 0);
  });

  test('the check-in step alone sends nothing but check-ins', () async {
    await workFiveStopsOffline();

    await sync.pushPendingCheckIns();

    expect(log, ['checkIns:ci-1,ci-2,ci-3,ci-4,ci-5']);
    expect(await local.countPendingCheckIns(), 0);
    expect(await local.countPendingVisitRecords(), 10);
  });

  test('a failing orders step never blocks the check-outs', () async {
    sync = VisitSyncRepositoryImpl(
      remote: remote,
      local: local,
      network: network,
      logger: logger,
      sendBeforeCaptures: () async => throw StateError('orders down'),
    );
    await local.insertCheckIn(checkIn(1));
    await local.insertCheckOut(checkOut(1));

    await sync.pushPendingVisitData();

    expect(log, ['checkIns:ci-1', 'checkOuts:co-1']);
    expect(await local.countPendingVisitRecords(), 0);
  });

  test(
      'saving only writes the phone; offering it offline wakes the sync '
      'engine', () async {
    var woken = 0;
    network.online = false;
    final visits = VisitRepositoryImpl(local,
        remote: _NoServer(), network: network, onQueued: () => woken++);
    final record = CheckInRecord(
      id: 'ci-9',
      stopId: 's-9',
      timestamp: morning,
      latitude: 11.55,
      longitude: 104.91,
      accuracyMeters: 8,
      distanceFromDepotMeters: 20,
      isMocked: false,
    );

    await visits.checkIn(record);
    expect(woken, 0, reason: 'the save alone sends nothing');
    await visits.sendCheckIn(record);
    await visits.checkOut(checkOut(9));
    await visits.sendCheckOut(checkOut(9));

    expect(woken, 2);
    expect(await local.countPendingVisitRecords(), 2);
  });

  test(
      'the Sync Center preview lists each stop with its shop name and '
      'what is still waiting, oldest first', () async {
    final day = DateTime.utc(2026, 10, 5);
    await db.into(db.routeDepots).insert(RouteDepotsCompanion.insert(
          id: 'd-2',
          name: 'Sok Hardware',
          nameKh: const Value('ហាងសុខ'),
          code: 'C-2',
          contact: 'Sok',
          phone: '012',
          address: 'St 1',
          territory: 'T1',
          territoryType: 'urban',
          latitude: 11.5,
          longitude: 104.9,
        ));
    await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
          id: 's-2',
          routeId: 'r-1',
          depotId: 'd-2',
          sequence: 2,
          status: 'checkedOut',
          plannedArrival: Value(day),
        ));
    await local.insertCheckIn(checkIn(2));
    await local.insertCheckOut(checkOut(2));
    await local.insertCheckOut(checkOut(1));
    await local.insertOrderLine(line(1));

    final pending =
        (await sync.fetchPendingVisits() as Success<PendingVisitSync>).data;

    expect(pending.stops.map((s) => s.stopId), ['s-1', 's-2']);
    expect(pending.stops[0].shopName, isNull,
        reason: 's-1 is not on the device; the UI says so');
    expect(pending.stops[0].checkInAt, isNull);
    expect(pending.stops[0].checkOutWaitsForCheckIn, isFalse);
    expect(pending.stops[1].shopName, 'Sok Hardware');
    expect(pending.stops[1].shopNameKh, 'ហាងសុខ');
    expect(pending.stops[1].checkOutWaitsForCheckIn, isTrue);
    // The order line belongs to s-1, so it is counted on that stop rather
    // than in an anonymous "other records" bucket the rep cannot act on.
    expect(pending.stops[0].orderLines, 1);
    expect(pending.otherRecords, 0);
  });
}

class _NoServer implements VisitCheckRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('offline: no request may be made');
}
