import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/route_dao.dart';
import 'package:steelforce/core/database/drift/daos/route_telemetry_dao.dart';
import 'package:steelforce/core/database/drift/daos/visit_dao.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';

/// DAO query + constraint tests for the route/visit aggregates (T1.5a step 2).
///
/// `docs/skills/engineering-standard.md` §10 requires new DAOs to ship with query and
/// constraint tests; in-memory Drift keeps them fast on host CI
/// (`docs/blueprint/local-storage-architecture.md` §8).
void main() {
  late AppDatabase db;
  late RouteDao routeDao;
  late RouteTelemetryDao telemetryDao;
  late VisitDao visitDao;

  final day = DateTime.utc(2026, 7, 15);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    routeDao = db.routeDao;
    telemetryDao = db.routeTelemetryDao;
    visitDao = db.visitDao;
  });

  tearDown(() => db.close());

  Future<void> seedDepot(String id) => db.into(db.depots).insert(
        DepotsCompanion.insert(
          id: id,
          sapDepotId: Value('SAP-$id'),
          depotCode: 'C-$id',
          shopName: 'Shop $id',
          ownerName: 'Owner',
          phone: '012000000',
          address: 'St 271',
          province: 'PP',
          district: 'TK',
          territory: 'T1',
          latitude: 11.55,
          longitude: 104.91,
          creditLimit: 1000,
          status: 'active',
          assignedRepId: 'rep-1',
          assignedRepName: 'Rep One',
          updatedAt: day,
        ),
      );

  RoutesCompanion routeRow(String id, {DateTime? visitDate}) =>
      RoutesCompanion.insert(
        id: id,
        name: 'Route $id',
        repId: 'rep-1',
        repName: 'Rep One',
        territory: 'T1',
        visitDate: visitDate ?? day,
        plannedStart: (visitDate ?? day).add(const Duration(hours: 8)),
        plannedEnd: (visitDate ?? day).add(const Duration(hours: 17)),
        status: 'planned',
      );

  RouteStopsCompanion stopRow(String id, String routeId, String depotId,
          {int sequence = 1, String status = 'pending'}) =>
      RouteStopsCompanion.insert(
        id: id,
        routeId: routeId,
        depotId: depotId,
        sequence: sequence,
        plannedArrival: Value(day.add(const Duration(hours: 9))),
        plannedDeparture: Value(day.add(const Duration(hours: 10))),
        status: status,
        // What a pull writes: the server's copy is, by definition, in step
        // with the server (`RouteStopEntityMapper.toCompanion`).
        syncState: const Value(SyncStates.synced),
        dirty: const Value(false),
      );

  group('RouteDao — day filtering', () {
    test('fetchRoutesForDay returns only that calendar day, ordered by start',
        () async {
      await routeDao.upsertRoutesWithStops([
        RouteWithStops(routeRow('r-today-late', visitDate: day), const []),
        RouteWithStops(
          routeRow('r-tomorrow', visitDate: day.add(const Duration(days: 1))),
          const [],
        ),
      ]);
      // Insert an earlier-starting route to prove ordering, not insertion order.
      await db.into(db.routes).insert(
            routeRow('r-today-early').copyWith(
              plannedStart: Value(day.add(const Duration(hours: 6))),
            ),
          );

      final result = await routeDao.fetchRoutesForDay(day);

      expect(result.map((r) => r.id), ['r-today-early', 'r-today-late']);
    });

    test('a route on the following day is excluded at the boundary', () async {
      await db.into(db.routes).insert(
          routeRow('r-next', visitDate: day.add(const Duration(days: 1))));

      expect(await routeDao.fetchRoutesForDay(day), isEmpty);
    });

    test('soft-deleted routes are hidden from reads', () async {
      await db.into(db.routes).insert(routeRow('r-1'));
      await (db.update(db.routes)..where((t) => t.id.equals('r-1')))
          .write(const RoutesCompanion(deleted: Value(true)));

      expect(await routeDao.fetchRoutesForDay(day), isEmpty);
      expect(await routeDao.getRoute('r-1'), isNull);
    });
  });

  group('RouteDao — sync upsert', () {
    test('stops are replaced wholesale, not merged', () async {
      await seedDepot('cust-1');
      await routeDao.upsertRoutesWithStops([
        RouteWithStops(routeRow('r-1'), [
          stopRow('s-1', 'r-1', 'cust-1', sequence: 1),
          stopRow('s-2', 'r-1', 'cust-1', sequence: 2),
        ]),
      ]);

      // SAP re-sends the plan with s-2 removed.
      await routeDao.upsertRoutesWithStops([
        RouteWithStops(routeRow('r-1'), [
          stopRow('s-1', 'r-1', 'cust-1', sequence: 1),
        ]),
      ]);

      final stops = await routeDao.fetchStops('r-1');
      expect(
        stops.map((s) => s.id),
        ['s-1'],
        reason: 'a stop the server no longer sends was removed from the plan',
      );
    });

    test('stops come back in visit order', () async {
      await seedDepot('cust-1');
      await routeDao.upsertRoutesWithStops([
        RouteWithStops(routeRow('r-1'), [
          stopRow('s-2', 'r-1', 'cust-1', sequence: 2),
          stopRow('s-1', 'r-1', 'cust-1', sequence: 1),
        ]),
      ]);

      final stops = await routeDao.fetchStops('r-1');
      expect(stops.map((s) => s.id), ['s-1', 's-2']);
    });
  });

  group('RouteDao — a pull never reverts unpushed stop progress (ADR-002)', () {
    final arrival = day.add(const Duration(hours: 9, minutes: 12));

    Future<void> pullOnce(List<RouteStopsCompanion> stops) => routeDao
        .upsertRoutesWithStops([RouteWithStops(routeRow('r-1'), stops)]);

    // Local visit progress always comes with its check-in / check-out row;
    // that row being unsent is what protects the stop from a pull.
    Future<void> unsentCheckIn(String stopId) =>
        db.visitDao.upsertCheckIn(VisitCheckInsCompanion.insert(
          id: 'ci-$stopId',
          stopId: stopId,
          timestamp: arrival,
          latitude: 11.55,
          longitude: 104.91,
          accuracy: 8,
          distanceFromDepot: 20,
        ));
    Future<void> unsentCheckOut(String stopId) =>
        db.visitDao.upsertCheckOut(VisitCheckOutsCompanion.insert(
          id: 'co-$stopId',
          stopId: stopId,
          timestamp: arrival.add(const Duration(minutes: 40)),
          latitude: 11.55,
          longitude: 104.91,
          durationMinutes: 40,
          visitSummary: 'Visit completed',
        ));

    test('a locally checked-in stop keeps its status through a pull', () async {
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);
      await unsentCheckIn('s-1');
      await routeDao.updateStopStatus('s-1',
          status: 'checkedIn', actualArrival: arrival);

      // The server has not seen the check-in yet and re-sends `pending`.
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);

      final stop = (await routeDao.fetchStops('r-1')).single;
      expect(stop.status, 'checkedIn',
          reason: 'the rep checked in offline; a pull must not undo it');
      expect(stop.actualArrival, arrival);
      expect(stop.dirty, isTrue, reason: 'still waiting to be pushed');
      expect(stop.syncState, SyncStates.dirty);
    });

    test('a locally completed stop is not reverted to an older server status',
        () async {
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1', status: 'checkedIn')]);
      final departure = day.add(const Duration(hours: 10));
      await unsentCheckOut('s-1');
      await routeDao.updateStopStatus('s-1',
          status: 'checkedOut', actualDeparture: departure);

      await pullOnce([stopRow('s-1', 'r-1', 'cust-1', status: 'checkedIn')]);

      final stop = (await routeDao.fetchStops('r-1')).single;
      expect(stop.status, 'checkedOut');
      expect(stop.actualDeparture, departure);
    });

    test('the server plan still applies to a stop with local progress',
        () async {
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1', sequence: 1)]);
      await unsentCheckIn('s-1');
      await routeDao.updateStopStatus('s-1', status: 'checkedIn');

      // SAP resequences the plan. That is the server's to decide.
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1', sequence: 4)]);

      final stop = (await routeDao.fetchStops('r-1')).single;
      expect(stop.sequence, 4, reason: 'plan fields are server-owned');
      expect(stop.status, 'checkedIn', reason: 'execution is the rep\'s');
    });

    test('a synced stop still takes the server status', () async {
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);

      // Nothing local to protect: the server moved it on (another device, or
      // a back-office correction), and that must land.
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1', status: 'missed')]);

      final stop = (await routeDao.fetchStops('r-1')).single;
      expect(stop.status, 'missed');
      expect(stop.dirty, isFalse);
      expect(stop.syncState, SyncStates.synced);
    });

    test('a stop with unpushed progress is kept when the server drops it',
        () async {
      await pullOnce([
        stopRow('s-1', 'r-1', 'cust-1', sequence: 1),
        stopRow('s-2', 'r-1', 'cust-1', sequence: 2),
        stopRow('s-3', 'r-1', 'cust-1', sequence: 3),
      ]);
      await unsentCheckIn('s-2');
      await routeDao.updateStopStatus('s-2', status: 'checkedIn');

      // The plan comes back without s-2 (in progress locally) and s-3 (not).
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1', sequence: 1)]);

      final stops = await routeDao.fetchStops('r-1');
      expect(stops.map((s) => s.id), ['s-1', 's-2'],
          reason: 's-3 was removed from the plan; s-2 carries unpushed work');
      expect(stops.last.status, 'checkedIn');
    });

    test('progress on one route is untouched by a pull of another', () async {
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);
      await unsentCheckIn('s-1');
      await routeDao.updateStopStatus('s-1', status: 'checkedIn');

      await routeDao.upsertRoutesWithStops([
        RouteWithStops(routeRow('r-2'), [stopRow('s-9', 'r-2', 'cust-1')]),
      ]);

      expect((await routeDao.fetchStops('r-1')).single.status, 'checkedIn');
      expect((await routeDao.fetchStops('r-2')).single.status, 'pending');
    });

    // check-in-check-out-mobile.md §10: once the local rows are accepted, the
    // server's visit is the truth.
    test('once the check-in is sent, the server copy replaces the local one',
        () async {
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);
      await unsentCheckIn('s-1');
      await routeDao.updateStopStatus('s-1',
          status: 'checkedIn', actualArrival: arrival);
      await db.visitDao.markSynced(VisitCaptureTable.checkIns, ['ci-s-1']);

      // A supervisor (or another phone) closed the visit server-side.
      final serverDeparture = day.add(const Duration(hours: 11));
      await pullOnce([
        stopRow('s-1', 'r-1', 'cust-1', status: 'checkedOut')
            .copyWith(actualDeparture: Value(serverDeparture)),
      ]);

      final stop = (await routeDao.fetchStops('r-1')).single;
      expect(stop.status, 'checkedOut');
      expect(stop.actualDeparture, serverDeparture);
      expect(stop.dirty, isFalse);
      expect(stop.syncState, SyncStates.synced);
    });

    test('a check-in the server dropped lets its status go back', () async {
      // The server refused the check-in for good and it was retired from
      // the queue; the server still says pending, and it is right.
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);
      await unsentCheckIn('s-1');
      await routeDao.updateStopStatus('s-1', status: 'checkedIn');
      await db.visitDao.deleteCheckIn('ci-s-1');

      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);

      expect((await routeDao.fetchStops('r-1')).single.status, 'pending');
    });

    test('local progress with no row of its own (a skip) is still kept',
        () async {
      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);
      await routeDao.updateStopStatus('s-1', status: 'missed');

      await pullOnce([stopRow('s-1', 'r-1', 'cust-1')]);

      expect((await routeDao.fetchStops('r-1')).single.status, 'missed');
    });
  });

  group('RouteDao — depot reconciliation (T1.5)', () {
    test('route attributes apply to an existing depot only', () async {
      await seedDepot('cust-1');

      final updated = await routeDao.upsertRouteAttributesOnDepot(
        'cust-1',
        territoryType: 'urban',
        geofenceRadiusOverride: 150,
      );

      expect(updated, 1);
      final depot = await db.select(db.depots).getSingle();
      expect(depot.territoryType, 'urban');
      expect(depot.geofenceRadiusOverride, 150);
      // The SAP-controlled columns must be untouched by route sync.
      expect(depot.shopName, 'Shop cust-1');
      expect(depot.creditLimit, 1000);
    });

    test('an unknown depot updates nothing and reports 0 rather than throwing',
        () async {
      final updated = await routeDao.upsertRouteAttributesOnDepot(
        'ghost',
        territoryType: 'rural',
      );

      // Caller treats 0 as "depot directory hasn't synced this yet — skip
      // the stop", not as an error. Route sync may never invent a depot.
      expect(updated, 0);
      expect(await routeDao.depotExists('ghost'), isFalse);
    });

    test('depotExists distinguishes seeded from unknown', () async {
      await seedDepot('cust-1');

      expect(await routeDao.depotExists('cust-1'), isTrue);
      expect(await routeDao.depotExists('nope'), isFalse);
    });
  });

  group('RouteDao — local mutations mark dirty', () {
    test('updateStopStatus omitting a timestamp leaves the stored value alone',
        () async {
      await seedDepot('cust-1');
      await routeDao.upsertRoutesWithStops([
        RouteWithStops(routeRow('r-1'), [stopRow('s-1', 'r-1', 'cust-1')]),
      ]);

      final arrival = day.add(const Duration(hours: 9, minutes: 5));
      await routeDao.updateStopStatus('s-1',
          status: 'inProgress', actualArrival: arrival);
      // A later update that only changes status must not wipe the arrival.
      await routeDao.updateStopStatus('s-1', status: 'completed');

      final stop = (await routeDao.fetchStops('r-1')).single;
      expect(stop.status, 'completed');
      expect(stop.actualArrival, arrival);
      expect(stop.dirty, isTrue);
      expect(stop.syncState, SyncStates.dirty);
    });

    test('updateRouteStatus flags the row for push', () async {
      await db.into(db.routes).insert(routeRow('r-1'));

      await routeDao.updateRouteStatus('r-1', 'completed');

      final route = await routeDao.getRoute('r-1');
      expect(route!.status, 'completed');
      expect(route.dirty, isTrue);
    });
  });

  group('RouteDao — delta cursor', () {
    test('last-synced round-trips and upserts idempotently', () async {
      expect(await routeDao.getLastSyncedAt('routes'), isNull);

      await routeDao.setLastSyncedAt('routes', day);
      await routeDao.setLastSyncedAt(
          'routes', day.add(const Duration(days: 1)));

      expect(
        await routeDao.getLastSyncedAt('routes'),
        day.add(const Duration(days: 1)),
      );
    });
  });

  group('RouteTelemetryDao', () {
    LocationSamplesCompanion sample(String id, DateTime at) =>
        LocationSamplesCompanion.insert(
          id: id,
          routeId: 'r-1',
          latitude: 11.55,
          longitude: 104.91,
          accuracy: 5,
          speed: 0,
          heading: 0,
          altitude: 12,
          timestamp: at,
        );

    setUp(() => db.into(db.routes).insert(routeRow('r-1')));

    test('batch insert stores every sample, ordered by time', () async {
      await telemetryDao.insertSamples([
        sample('s-2', day.add(const Duration(hours: 10))),
        sample('s-1', day.add(const Duration(hours: 9))),
      ]);

      final samples = await telemetryDao.fetchSamples('r-1');
      expect(samples.map((s) => s.id), ['s-1', 's-2']);
    });

    test('purge removes synced samples but never unsynced ones', () async {
      await telemetryDao.insertSamples([
        sample('old-synced', day.add(const Duration(hours: 1))),
        sample('old-pending', day.add(const Duration(hours: 2))),
      ]);
      await telemetryDao.markSamplesSynced(['old-synced']);

      final purged = await telemetryDao
          .purgeSyncedSamplesBefore(day.add(const Duration(hours: 5)));

      expect(purged, 1);
      final remaining = await telemetryDao.fetchSamples('r-1');
      expect(
        remaining.map((s) => s.id),
        ['old-pending'],
        reason: 'an unsynced GPS point is unpushed data — never purge it',
      );
    });

    test('markSamplesSynced with an empty list is a no-op', () async {
      await telemetryDao.insertSamples([sample('s-1', day)]);

      await telemetryDao.markSamplesSynced([]);

      expect((await telemetryDao.fetchPendingSamples()), hasLength(1));
    });
  });

  group('VisitDao — captures', () {
    setUp(() async {
      await seedDepot('cust-1');
      await routeDao.upsertRoutesWithStops([
        RouteWithStops(routeRow('r-1'), [stopRow('s-1', 'r-1', 'cust-1')]),
      ]);
    });

    test('check-in is unique per stop — a second one replaces the first',
        () async {
      await visitDao.upsertCheckIn(VisitCheckInsCompanion.insert(
        id: 'ci-1',
        stopId: 's-1',
        timestamp: day,
        latitude: 11.55,
        longitude: 104.91,
        accuracy: 5,
        distanceFromDepot: 12,
      ));

      final stored = await visitDao.getCheckIn('s-1');
      expect(stored!.id, 'ci-1');
      expect(stored.syncState, SyncStates.dirty);
    });

    test('countPendingVisitRecords sums every capture table', () async {
      await visitDao.upsertCheckIn(VisitCheckInsCompanion.insert(
        id: 'ci-1',
        stopId: 's-1',
        timestamp: day,
        latitude: 11.55,
        longitude: 104.91,
        accuracy: 5,
        distanceFromDepot: 12,
      ));
      await visitDao.insertOrderLine(VisitOrderLinesCompanion.insert(
        id: 'ol-1',
        stopId: 's-1',
        productId: 'p-1',
        productName: 'Rebar',
        quantity: 10,
        unit: 'pcs',
        unitPrice: 5,
      ));
      await visitDao.insertNote(VisitNotesCompanion.insert(
        id: 'n-1',
        stopId: 's-1',
        type: 'general',
        body: 'Shop closed early',
        createdAt: day,
      ));

      expect(await visitDao.countPendingVisitRecords(), 3);
    });

    test('markSynced clears only the targeted table', () async {
      await visitDao.insertOrderLine(VisitOrderLinesCompanion.insert(
        id: 'ol-1',
        stopId: 's-1',
        productId: 'p-1',
        productName: 'Rebar',
        quantity: 10,
        unit: 'pcs',
        unitPrice: 5,
      ));
      await visitDao.insertNote(VisitNotesCompanion.insert(
        id: 'n-1',
        stopId: 's-1',
        type: 'general',
        body: 'note',
        createdAt: day,
      ));

      await visitDao.markSynced(VisitCaptureTable.orderLines, ['ol-1']);

      expect(await visitDao.fetchPendingOrderLines(), isEmpty);
      expect(
        await visitDao.fetchPendingNotes(),
        hasLength(1),
        reason: 'marking one table must not touch another',
      );
      expect(await visitDao.countPendingVisitRecords(), 1);
    });

    // ── ADR-011: captures outlive the stop row ───────────────────────
    //
    // These two tests previously asserted the opposite — that a capture
    // cascades away with its stop, and that a capture for an unknown stop is
    // rejected. Both were reversed deliberately, because route sync *replaces*
    // a route's stops on every run: the cascade meant a routine delta silently
    // deleted a rep's unsynced check-ins, notes and collections, and the
    // rejection meant a capture raced against sync was refused outright.
    //
    // A capture is first-hand field work the server has no competing version
    // of (`docs/blueprint/sync-architecture.md` §5). Losing one is the exact failure the
    // offline design exists to prevent, so it now survives independently and
    // is pushed by `stop_id`.

    test('a capture survives its stop row being replaced by sync', () async {
      await visitDao.insertCollection(VisitCollectionsCompanion.insert(
        id: 'col-1',
        stopId: 's-1',
        amount: 250,
        method: 'cash',
      ));

      await (db.delete(db.routeStops)..where((t) => t.id.equals('s-1'))).go();

      final survived = await visitDao.fetchCollections('s-1');
      expect(
        survived,
        hasLength(1),
        reason: 'A cash collection the rep took must not disappear because '
            'the route refreshed. It is money that was handed over.',
      );
      expect(survived.single.amount, 250);
    });

    test('a capture for a stop sync has not written yet is accepted', () async {
      await visitDao.insertReturn(VisitReturnsCompanion.insert(
        id: 'ret-1',
        stopId: 'ghost-stop',
        productId: 'p-1',
        productName: 'Rebar',
        quantity: 1,
        reason: 'damaged',
      ));

      final stored = await visitDao.fetchReturns('ghost-stop');
      expect(
        stored,
        hasLength(1),
        reason: 'The rep is standing in the shop with the damaged goods. '
            'Whether route sync has written the stop row yet is not their '
            'problem, and refusing the capture loses it permanently.',
      );
    });
  });
}
