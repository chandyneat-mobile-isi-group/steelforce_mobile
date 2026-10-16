// `isNull` is hidden: drift exports a SQL `isNull` expression builder that
// collides with matcher's null matcher, and here we want the matcher.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/route_dao.dart';

/// Regression tests for ADR-011.
///
/// Both scenarios below are transcripts of failures that were reproduced
/// against the pre-ADR-011 schema. They are written as behaviour ("the rep
/// keeps their day", "the capture survives") rather than as schema assertions,
/// because the schema is only the current means — what must never regress is
/// the outcome.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  RoutesCompanion route(String id) => RoutesCompanion.insert(
        id: id,
        name: 'Tuesday, PP-NORTH',
        repId: 'rep-1',
        repName: 'Rep One',
        territory: 'PP-NORTH',
        visitDate: DateTime.utc(2026, 8, 24),
        plannedStart: DateTime.utc(2026, 8, 24, 8),
        plannedEnd: DateTime.utc(2026, 8, 24, 17),
        status: 'published',
      );

  RouteStopsCompanion stop(String id, String depotId, int sequence) =>
      RouteStopsCompanion.insert(
        id: id,
        routeId: 'r1',
        depotId: depotId,
        sequence: sequence,
        plannedArrival: Value(DateTime.utc(2026, 8, 24, 8 + sequence)),
        plannedDeparture: Value(DateTime.utc(2026, 8, 24, 9 + sequence)),
        status: 'pending',
      );

  RouteDepotsCompanion routeDepot(String id) => RouteDepotsCompanion.insert(
        id: id,
        name: 'Shop $id',
        code: 'C-$id',
        contact: 'Owner',
        phone: '012000000',
        address: 'Street 271',
        territory: 'PP-NORTH',
        territoryType: 'urban',
        latitude: 11.5,
        longitude: 104.9,
      );

  group('a route survives depots the directory has not pulled', () {
    test('every stop persists, including the unknown-depot one', () async {
      // The depot directory is deliberately left EMPTY. Under the old
      // schema `route_stops.depot_id -> depots` made this abort the whole
      // transaction with SqliteException(787), and the rep lost all five stops.
      await db.routeDao.upsertRoutesWithStops([
        RouteWithStops(route('r1'), [
          stop('s1', 'cust-1', 1),
          stop('s2', 'cust-1', 2),
          stop('s3', 'NEVER-SYNCED', 3),
          stop('s4', 'cust-2', 4),
          stop('s5', 'cust-1', 5),
        ]),
      ]);

      final stops = await db.routeDao.fetchStops('r1');
      expect(stops, hasLength(5),
          reason: 'One unrecognised depot must not cost the rep the day.');
      expect(
          stops.map((s) => s.id), containsAll(['s1', 's2', 's3', 's4', 's5']));
    });

    test('the stop still reaches the UI, with its depot details', () async {
      await db.routeDao.upsertRouteDepots([routeDepot('cust-1')]);
      await db.routeDao.upsertRoutesWithStops([
        RouteWithStops(route('r1'), [
          stop('s1', 'cust-1', 1),
          stop('s2', 'NEVER-SYNCED', 2),
        ]),
      ]);

      final joined = await db.routeDao.fetchStopsWithDepots('r1');

      // A LEFT join, so the depot-less stop is still returned rather than
      // silently filtered out -- the same data loss the FK caused, just quiet.
      expect(joined, hasLength(2));
      expect(joined.first.depot?.name, 'Shop cust-1');
      expect(joined.last.depot, isNull);
    });
  });

  group('re-syncing a route preserves captured field work', () {
    Future<void> seedCapture() async {
      await db.customStatement(
        'INSERT INTO visit_check_ins (id, stop_id, timestamp, latitude, '
        'longitude, accuracy, distance_from_depot, is_mocked) '
        "VALUES ('ci1','s1',0,11.5,104.9,5.0,12.0,0)",
      );
      await db.customStatement(
        'INSERT INTO visit_notes (id, stop_id, type, text, created_at) '
        "VALUES ('n1','s1','general','Wants a rebar quote',0)",
      );
      await db.customStatement(
        'INSERT INTO fraud_flags (id, route_id, stop_id, type, detail, '
        "timestamp, blocked) VALUES ('f1','r1','s1','mockLocation','x',0,0)",
      );
    }

    test(
        'a delta that re-sends the same route keeps check-ins, notes and '
        'fraud flags', () async {
      await db.routeDao.upsertRoutesWithStops([
        RouteWithStops(route('r1'), [stop('s1', 'cust-1', 1)]),
      ]);
      await seedCapture();

      // Exactly what the backend documents as normal: a delta may re-send the
      // complete current set (docs/feature/my-visits/api.md §5.2). Under the old
      // schema the stop replacement cascaded and erased all three rows.
      await db.routeDao.upsertRoutesWithStops([
        RouteWithStops(route('r1'), [stop('s1', 'cust-1', 1)]),
      ]);

      final counts = (await db
              .customSelect('SELECT '
                  '(SELECT COUNT(*) FROM visit_check_ins) a, '
                  '(SELECT COUNT(*) FROM visit_notes) b, '
                  '(SELECT COUNT(*) FROM fraud_flags) c')
              .getSingle())
          .data;

      expect(counts['a'], 1, reason: 'check-in destroyed by a routine re-sync');
      expect(counts['b'], 1, reason: 'note destroyed by a routine re-sync');
      expect(counts['c'], 1, reason: 'fraud flag destroyed by a re-sync');
    });
  });

  test('storing the feed\'s depots twice converges, never duplicates',
      () async {
    // Sync is retried freely on a flaky connection, so the write has to be
    // idempotent rather than merely correct once.
    await db.routeDao.upsertRouteDepots([routeDepot('cust-1')]);
    await db.routeDao.upsertRouteDepots([
      routeDepot('cust-1').copyWith(name: const Value('Renamed Shop')),
    ]);

    final rows = await db.select(db.routeDepots).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Renamed Shop',
        reason: 'the later sync is the fresher truth');
  });
}
