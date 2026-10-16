import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_route_source.dart';
import 'package:steelforce/core/database/drift/migrations/legacy/legacy_routes_importer.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// In-memory stand-in for the plaintext `routes.db`.
///
/// Hand-written rather than mocked: the rows *are* the input to the logic under
/// test, and a mock returning canned values would let the mapping rules go
/// unverified (`docs/skills/ai-engineering-playbook.md` §7.6). Values are deliberately
/// stored in legacy shapes — ISO date strings, 0/1 integers for booleans — so
/// the coercion path is exercised for real.
class _FakeLegacySource implements LegacyRouteSource {
  _FakeLegacySource(this.tables, {this.present = true});

  final Map<String, List<Map<String, Object?>>> tables;
  final bool present;
  final List<String> purged = [];
  bool closed = false;

  @override
  Future<bool> exists() async => present;

  @override
  Future<List<Map<String, Object?>>> readTable(String table) async =>
      tables[table] ?? const [];

  @override
  Future<void> deleteAllRows(String table) async => purged.add(table);

  @override
  Future<void> close() async => closed = true;
}

void main() {
  late AppDatabase db;
  const logger = ConsoleAppLogger(verbose: false);

  final visitDay = DateTime.utc(2026, 7, 15);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
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
          creditLimit: 5000,
          status: 'active',
          assignedRepId: 'rep-1',
          assignedRepName: 'Rep One',
          updatedAt: visitDay,
        ),
      );

  Map<String, List<Map<String, Object?>>> legacyFixture() => {
        'depots': [
          {
            'id': 'cust-1',
            'name': 'ISI Hardware',
            'code': 'C-1',
            'contact': 'Sok',
            'phone': '012345678',
            'address': 'St 271',
            'territory': 'T1',
            'territory_type': 'urban',
            'latitude': 11.55,
            'longitude': 104.91,
            'geofence_radius_override': 150.0,
          },
        ],
        'routes': [
          {
            'id': 'r-1',
            'name': 'North loop',
            'rep_id': 'rep-1',
            'rep_name': 'Rep One',
            'territory': 'T1',
            'visit_date': '2026-07-15T00:00:00.000Z',
            'planned_start': '2026-07-15T08:00:00.000Z',
            'planned_end': '2026-07-15T17:00:00.000Z',
            'status': 'inProgress',
          },
        ],
        'stops': [
          {
            'id': 's-1',
            'route_id': 'r-1',
            'depot_id': 'cust-1',
            'sequence': 1,
            'planned_arrival': '2026-07-15T09:00:00.000Z',
            'planned_departure': '2026-07-15T10:00:00.000Z',
            'status': 'completed',
            'actual_arrival': '2026-07-15T09:05:00.000Z',
            'actual_departure': null,
          },
        ],
        'location_samples': [
          {
            'id': 'ls-1',
            'route_id': 'r-1',
            'latitude': 11.55,
            'longitude': 104.91,
            'accuracy': 5.0,
            'speed': 0.0,
            'heading': 0.0,
            'altitude': 12.0,
            'timestamp': '2026-07-15T09:01:00.000Z',
            'is_mocked': 1,
          },
        ],
        'checkins': [
          {
            'id': 'ci-1',
            'stop_id': 's-1',
            'timestamp': '2026-07-15T09:05:00.000Z',
            'latitude': 11.55,
            'longitude': 104.91,
            'accuracy': 5.0,
            'distance_from_depot': 12.0,
            'is_mocked': 0,
            'sync_status': 'pending',
          },
        ],
        'visit_collections': [
          {
            'id': 'col-1',
            'stop_id': 's-1',
            'amount': 250.0,
            'method': 'cash',
            'reference': 'RC-1',
            'notes': '',
            'sync_status': 'synced',
          },
        ],
        'visit_notes': [
          {
            'id': 'n-1',
            'stop_id': 's-1',
            'type': 'general',
            'text': 'Shop closed early',
            'created_at': '2026-07-15T09:30:00.000Z',
            'sync_status': 'pending',
          },
        ],
        'fraud_flags': [
          {
            'id': 'ff-1',
            'route_id': 'r-1',
            'stop_id': 'ghost-stop',
            'type': 'mockedGps',
            'detail': 'mock provider',
            'timestamp': '2026-07-15T09:02:00.000Z',
            'blocked': 1,
          },
        ],
        'sync_meta': [
          {'entity': 'routes', 'last_synced_at': '2026-07-14T00:00:00.000Z'},
        ],
      };

  LegacyRoutesImporter importerFor(_FakeLegacySource source) =>
      LegacyRoutesImporter(db: db, source: source, logger: logger);

  group('guards', () {
    test('a fresh install with no legacy file is a no-op, marked done',
        () async {
      final source = _FakeLegacySource({}, present: false);

      final result = await importerFor(source).import();

      expect(result.sourceMissing, isTrue);
      expect(result.totalImported, 0);
      // Marked so a later restore-from-backup can't re-trigger a stale import.
      expect(
        await db.appMetadataDao.getValue(LegacyRoutesImporter.importedAtKey),
        isNotNull,
      );
    });

    test('a completed import never runs twice', () async {
      await seedDepot('cust-1');
      final source = _FakeLegacySource(legacyFixture());
      await importerFor(source).import();

      final second = await importerFor(source).import();

      expect(second.alreadyDone, isTrue);
      expect(await db.select(db.routes).get(), hasLength(1));
    });

    test('re-running is idempotent — no duplicate rows', () async {
      await seedDepot('cust-1');
      // Force a genuine second pass by clearing the completion marker.
      await importerFor(_FakeLegacySource(legacyFixture())).import();
      await db.appMetadataDao.setValue(LegacyRoutesImporter.importedAtKey, '');
      await (db.delete(db.appMetadata)
            ..where((t) => t.key.equals(LegacyRoutesImporter.importedAtKey)))
          .go();

      await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect(await db.select(db.routes).get(), hasLength(1));
      expect(await db.select(db.visitNotes).get(), hasLength(1));
    });
  });

  group('mapping', () {
    setUp(() => seedDepot('cust-1'));

    test('routes and stops import with legacy ISO dates parsed', () async {
      await importerFor(_FakeLegacySource(legacyFixture())).import();

      final route = await db.select(db.routes).getSingle();
      expect(route.id, 'r-1');
      expect(route.status, 'inProgress');
      expect(route.visitDate, visitDay);

      final stop = await db.select(db.routeStops).getSingle();
      expect(stop.actualArrival, DateTime.utc(2026, 7, 15, 9, 5));
      expect(stop.actualDeparture, isNull);
    });

    test('a SAP-owned route plan imports as synced, not as a pending push',
        () async {
      await importerFor(_FakeLegacySource(legacyFixture())).import();

      final route = await db.select(db.routes).getSingle();
      expect(route.syncState, SyncStates.synced);
      expect(route.dirty, isFalse);
    });

    test('stop execution status imports as dirty — it still owes SAP a push',
        () async {
      await importerFor(_FakeLegacySource(legacyFixture())).import();

      final stop = await db.select(db.routeStops).getSingle();
      expect(stop.syncState, SyncStates.dirty);
      expect(stop.dirty, isTrue);
    });

    test("legacy sync_status 'pending' becomes dirty, 'synced' stays synced",
        () async {
      await importerFor(_FakeLegacySource(legacyFixture())).import();

      final checkIn = await db.select(db.visitCheckIns).getSingle();
      expect(checkIn.syncState, SyncStates.dirty);
      expect(checkIn.dirty, isTrue);

      final collection = await db.select(db.visitCollections).getSingle();
      expect(collection.syncState, SyncStates.synced);
      expect(collection.dirty, isFalse);
    });

    test('legacy 0/1 integers coerce to booleans', () async {
      await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect(
          (await db.select(db.locationSamples).getSingle()).isMocked, isTrue);
      expect((await db.select(db.visitCheckIns).getSingle()).isMocked, isFalse);
      expect((await db.select(db.fraudFlags).getSingle()).blocked, isTrue);
    });

    test("visit_notes.text maps onto the renamed body column", () async {
      await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect((await db.select(db.visitNotes).getSingle()).body,
          'Shop closed early');
    });

    test('the delta cursor carries over', () async {
      await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect(await db.routeDao.getLastSyncedAt('routes'),
          DateTime.utc(2026, 7, 14));
    });
  });

  group('depot reconciliation', () {
    test('the legacy depot copy is absorbed, never imported as a depot',
        () async {
      await seedDepot('cust-1');

      await importerFor(_FakeLegacySource(legacyFixture())).import();

      final depots = await db.select(db.depots).get();
      expect(
        depots,
        hasLength(1),
        reason: 'the legacy denormalised copy must not create a second row',
      );
      final c = depots.single;
      // Only the two genuinely-unique fields are taken.
      expect(c.territoryType, 'urban');
      expect(c.geofenceRadiusOverride, 150.0);
      // The SAP-controlled columns are untouched — the legacy copy carried a
      // different name ('ISI Hardware') and no credit limit at all.
      expect(c.shopName, 'Shop cust-1');
      expect(c.creditLimit, 5000);
      expect(c.sapDepotId, 'SAP-cust-1');
    });
  });

  group('orphan reconciliation — the reason this is not a blind copy', () {
    test('a stop whose depot never synced is skipped, not fatal', () async {
      // No seedDepot: the directory does not know cust-1.
      final result =
          await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect(result.imported['routes'], 1);
      expect(result.imported['stops'], 0);
      expect(result.skipped['stops'], 1);
      expect(await db.select(db.routeStops).get(), isEmpty);
    });

    test('captures of a skipped stop are skipped too, without an FK crash',
        () async {
      final result =
          await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect(result.skipped['checkins'], 1);
      expect(result.skipped['visit_notes'], 1);
      expect(await db.select(db.visitCheckIns).get(), isEmpty);
    });

    test('skipped rows block the purge — they exist only in the plaintext file',
        () async {
      final result =
          await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect(result.totalSkipped, greaterThan(0));
      expect(
        result.safeToPurge,
        isFalse,
        reason: 'purging would destroy rows that were never imported',
      );
    });

    test('a clean import is safe to purge', () async {
      await seedDepot('cust-1');

      final result =
          await importerFor(_FakeLegacySource(legacyFixture())).import();

      expect(result.totalSkipped, 0);
      expect(result.safeToPurge, isTrue);
    });

    test('a fraud flag with a dangling stop survives with a null stop',
        () async {
      await seedDepot('cust-1');

      await importerFor(_FakeLegacySource(legacyFixture())).import();

      final flag = await db.select(db.fraudFlags).getSingle();
      expect(flag.id, 'ff-1');
      expect(
        flag.stopId,
        isNull,
        reason: 'a fraud signal is evidence — drop the bad ref, keep the flag',
      );
    });
  });

  group('failure handling', () {
    test('a malformed row rolls the whole import back and leaves no marker',
        () async {
      await seedDepot('cust-1');
      final broken = legacyFixture();
      // A route with an unparseable required date: `_dt(...)!` throws.
      broken['routes']!.add({
        'id': 'r-bad',
        'name': 'Broken',
        'rep_id': 'rep-1',
        'rep_name': 'Rep',
        'territory': 'T1',
        'visit_date': 'not-a-date',
        'planned_start': 'not-a-date',
        'planned_end': 'not-a-date',
        'status': 'planned',
      });

      await expectLater(
        importerFor(_FakeLegacySource(broken)).import(),
        throwsA(isA<Object>()),
      );

      // All-or-nothing: the encrypted DB is untouched and the plaintext source
      // is intact, so a fixed retry is safe.
      expect(await db.select(db.routes).get(), isEmpty);
      expect(
        await db.appMetadataDao.getValue(LegacyRoutesImporter.importedAtKey),
        isNull,
      );
    });
  });

  group('purge', () {
    test('purge empties every business table and closes the source', () async {
      await seedDepot('cust-1');
      final source = _FakeLegacySource(legacyFixture());
      final importer = importerFor(source);
      await importer.import();

      await importer.purgeLegacyData();

      expect(source.purged, containsAll(['depots', 'stops', 'routes']));
      expect(
        source.purged,
        isNot(contains('workflow_state')),
        reason: 'workflow_state is still live until ADR-007 lands (Phase 3)',
      );
      expect(source.closed, isTrue);
    });
  });
}
