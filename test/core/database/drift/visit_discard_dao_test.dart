import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/visit_dao.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';

/// `VisitDao.discardUnsentStopWork` — the Sync Center's Discard on a visit.
///
/// What must hold: only unsent (`dirty`) rows go, synced rows and other stops
/// are untouched, and the stop is reset by what was discarded — all in one
/// transaction.
void main() {
  late AppDatabase db;
  late VisitDao dao;

  final day = DateTime.utc(2026, 10, 5, 1);
  const dirty = SyncStates.dirty;
  const synced = SyncStates.synced;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.visitDao;
  });

  tearDown(() => db.close());

  Future<void> seedStop(String id, {String status = 'checkedOut'}) =>
      db.into(db.routeStops).insert(RouteStopsCompanion.insert(
            id: id,
            routeId: 'r-1',
            depotId: 'd-$id',
            sequence: 1,
            status: status,
            plannedArrival: Value(day),
            actualArrival: Value(day.add(const Duration(hours: 1))),
            actualDeparture: Value(day.add(const Duration(hours: 2))),
            dirty: const Value(true),
            syncState: const Value(dirty),
          ));

  Future<void> checkIn(String stop, String state) =>
      dao.upsertCheckIn(VisitCheckInsCompanion.insert(
        id: 'ci-$stop',
        stopId: stop,
        timestamp: day,
        latitude: 11.5,
        longitude: 104.9,
        accuracy: 5,
        distanceFromDepot: 10,
        syncState: Value(state),
      ));

  Future<void> checkOut(String stop, String state) =>
      dao.upsertCheckOut(VisitCheckOutsCompanion.insert(
        id: 'co-$stop',
        stopId: stop,
        timestamp: day.add(const Duration(minutes: 40)),
        latitude: 11.5,
        longitude: 104.9,
        durationMinutes: 40,
        visitSummary: 'done',
        syncState: Value(state),
      ));

  /// One row in each of the six capture tables for [stop], in [state].
  Future<void> captures(String stop, String state, {String tag = ''}) async {
    await dao.insertOrderLine(VisitOrderLinesCompanion.insert(
      id: 'ol-$stop$tag',
      stopId: stop,
      productId: 'P1',
      productName: 'Rebar',
      quantity: 2,
      unit: 'pcs',
      unitPrice: 4,
      syncState: Value(state),
    ));
    await dao.insertStockUpdate(VisitStockUpdatesCompanion.insert(
      id: 'su-$stop$tag',
      stopId: Value(stop),
      productId: 'P1',
      productName: 'Rebar',
      stockLevel: 'low',
      syncState: Value(state),
    ));
    await dao.insertReturn(VisitReturnsCompanion.insert(
      id: 're-$stop$tag',
      stopId: stop,
      productId: 'P1',
      productName: 'Rebar',
      quantity: 1,
      reason: 'bent',
      syncState: Value(state),
    ));
    await dao.insertCollection(VisitCollectionsCompanion.insert(
      id: 'cl-$stop$tag',
      stopId: stop,
      amount: 10,
      method: 'cash',
      syncState: Value(state),
    ));
    await dao.insertNote(VisitNotesCompanion.insert(
      id: 'no-$stop$tag',
      stopId: stop,
      type: 'general',
      body: 'note',
      createdAt: day,
      syncState: Value(state),
    ));
    await dao.insertPhoto(VisitPhotosCompanion.insert(
      id: 'ph-$stop$tag',
      stopId: stop,
      path: '/tmp/$stop$tag.jpg',
      takenAt: day,
      syncState: Value(state),
    ));
  }

  Future<RouteStopRow> stopRow(String id) =>
      (db.select(db.routeStops)..where((t) => t.id.equals(id))).getSingle();

  Future<DiscardedStopWork> discard(String stopId) => dao.discardUnsentStopWork(
        stopId,
        notVisitedStatus: 'pending',
        checkedInStatus: 'checkedIn',
      );

  test(
      'an unsent check-in: every unsent row goes, the stop is not visited '
      'again and the resume pointer at it is cleared', () async {
    await seedStop('s-1');
    await checkIn('s-1', dirty);
    await checkOut('s-1', dirty);
    await captures('s-1', dirty);
    await db.into(db.workflowState).insert(WorkflowStateCompanion.insert(
          id: 'active',
          routeId: 'r-1',
          currentStopId: const Value('s-1'),
          updatedAt: day.toIso8601String(),
        ));

    final result = await discard('s-1');

    expect(result.reset, StopResetKind.notVisited);
    expect(result.rowsDeleted, 8);
    expect(result.photoPaths, ['/tmp/s-1.jpg']);
    expect(await dao.countPendingVisitRecords(), 0);
    expect(await dao.checkInForStop('s-1'), isNull);

    final stop = await stopRow('s-1');
    expect(stop.status, 'pending');
    expect(stop.actualArrival, isNull);
    expect(stop.actualDeparture, isNull);
    expect(stop.dirty, isFalse,
        reason: 'nothing local left to push; the server copy is the truth');
    expect(stop.syncState, synced);
    expect(await db.workflowStateDao.getActive(), isNull);
  });

  test(
      'a synced check-in with an unsent check-out: back to checked in, '
      'arrival kept, departure cleared, the check-in row kept', () async {
    await seedStop('s-1');
    await checkIn('s-1', synced);
    await checkOut('s-1', dirty);
    await db.into(db.workflowState).insert(WorkflowStateCompanion.insert(
          id: 'active',
          routeId: 'r-1',
          currentStopId: const Value('s-1'),
          updatedAt: day.toIso8601String(),
        ));

    final result = await discard('s-1');

    expect(result.reset, StopResetKind.checkedIn);
    expect(result.rowsDeleted, 1);
    expect(await dao.checkInForStop('s-1'), isNotNull);
    expect(await dao.getCheckOut('s-1'), isNull);

    final stop = await stopRow('s-1');
    expect(stop.status, 'checkedIn');
    expect(stop.actualArrival, isNotNull);
    expect(stop.actualDeparture, isNull);
    expect(await db.workflowStateDao.getActive(), isNotNull,
        reason: 'the visit is still checked in; the pointer stays');
  });

  test(
      'only captures unsent (check-in and check-out synced): the stop is not '
      'touched and synced captures are kept', () async {
    await seedStop('s-1');
    await checkIn('s-1', synced);
    await checkOut('s-1', synced);
    await captures('s-1', synced, tag: '-old');
    await captures('s-1', dirty);

    final result = await discard('s-1');

    expect(result.reset, StopResetKind.unchanged);
    expect(result.rowsDeleted, 6);
    expect(result.photoPaths, ['/tmp/s-1.jpg']);
    expect(await dao.countPendingVisitRecords(), 0);
    expect((await dao.fetchPhotos('s-1')).map((p) => p.id), ['ph-s-1-old']);
    expect((await dao.fetchOrderLines('s-1')).map((p) => p.id), ['ol-s-1-old']);

    final stop = await stopRow('s-1');
    expect(stop.status, 'checkedOut');
    expect(stop.actualDeparture, isNotNull);
    expect(stop.dirty, isTrue, reason: 'untouched');
  });

  test('other stops, their rows and their resume pointer are untouched',
      () async {
    await seedStop('s-1');
    await seedStop('s-2', status: 'checkedIn');
    await checkIn('s-1', dirty);
    await checkIn('s-2', dirty);
    await captures('s-2', dirty);
    await db.into(db.workflowState).insert(WorkflowStateCompanion.insert(
          id: 'active',
          routeId: 'r-1',
          currentStopId: const Value('s-2'),
          updatedAt: day.toIso8601String(),
        ));

    await discard('s-1');

    expect(await dao.checkInForStop('s-2'), isNotNull);
    expect(await dao.countPendingVisitRecords(), 7);
    expect((await stopRow('s-2')).status, 'checkedIn');
    expect(await db.workflowStateDao.getActive(), isNotNull,
        reason: 'the pointer is at another stop');
  });

  test('a stock count with no stop is never taken by a stop discard', () async {
    await seedStop('s-1');
    await checkIn('s-1', dirty);
    await dao.insertStockUpdate(VisitStockUpdatesCompanion.insert(
      id: 'su-depot',
      depotId: const Value('d-9'),
      productId: 'P1',
      productName: 'Rebar',
      stockLevel: 'high',
    ));

    await discard('s-1');

    expect(await dao.countPendingVisitRecords(), 1);
  });
}
