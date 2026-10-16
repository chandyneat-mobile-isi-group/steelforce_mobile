import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/fraud_flag_model.dart';
import 'package:steelforce/features/my_visits/data/models/location_sample_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';

/// Parity tests for the T1.5 telemetry cutover.
///
/// These assert the **interface contract** rather than the implementation: the
/// swap from plaintext sqflite to the encrypted Drift database must be invisible
/// to the repository above (ADR-003 seam). If any expectation here had to change
/// to accommodate Drift, that would mean the "refactor" changed behaviour —
/// which `docs/skills/ai-engineering-playbook.md` §8 says makes it not a refactor.
void main() {
  late AppDatabase db;
  late LocationSampleDriftLocalDataSource dataSource;

  final day = DateTime.utc(2026, 7, 15);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dataSource = LocationSampleDriftLocalDataSource(db.routeTelemetryDao);
    // Telemetry hangs off a route by FK — seed one.
    await db.into(db.routes).insert(
          RoutesCompanion.insert(
            id: 'r-1',
            name: 'North loop',
            repId: 'rep-1',
            repName: 'Rep One',
            territory: 'T1',
            visitDate: day,
            plannedStart: day.add(const Duration(hours: 8)),
            plannedEnd: day.add(const Duration(hours: 17)),
            status: 'inProgress',
          ),
        );
  });

  tearDown(() => db.close());

  LocationSampleModel sample(String id, {DateTime? at, bool mocked = false}) =>
      LocationSampleModel(
        id: id,
        routeId: 'r-1',
        latitude: 11.55,
        longitude: 104.91,
        accuracyMeters: 5,
        speedMps: 1.5,
        headingDegrees: 90,
        altitudeMeters: 12,
        timestamp: at ?? day.add(const Duration(hours: 9)),
        isMocked: mocked,
      );

  group('location samples', () {
    test('a sample round-trips with every field intact', () async {
      final original = sample('ls-1', mocked: true);

      await dataSource.insertSample(original);
      final stored = (await dataSource.fetchSamples('r-1')).single;

      expect(stored.id, 'ls-1');
      expect(stored.routeId, 'r-1');
      expect(stored.latitude, 11.55);
      expect(stored.longitude, 104.91);
      expect(stored.accuracyMeters, 5);
      expect(stored.speedMps, 1.5);
      expect(stored.headingDegrees, 90);
      expect(stored.altitudeMeters, 12);
      expect(stored.timestamp, original.timestamp);
      expect(stored.isMocked, isTrue);
    });

    test('samples come back oldest-first', () async {
      await dataSource
          .insertSample(sample('ls-2', at: day.add(const Duration(hours: 10))));
      await dataSource
          .insertSample(sample('ls-1', at: day.add(const Duration(hours: 9))));

      final samples = await dataSource.fetchSamples('r-1');

      expect(samples.map((s) => s.id), ['ls-1', 'ls-2']);
    });

    test('an unknown route returns empty, not an error', () async {
      expect(await dataSource.fetchSamples('ghost-route'), isEmpty);
    });

    test('a sample for a non-existent route surfaces as CacheException',
        () async {
      // The FK rejects it. The repository above expects CacheException, not a
      // raw SqliteException leaking the storage engine (ENGINEERING_STANDARD §7).
      final orphan = LocationSampleModel(
        id: 'ls-x',
        routeId: 'ghost-route',
        latitude: 0,
        longitude: 0,
        accuracyMeters: 0,
        speedMps: 0,
        headingDegrees: 0,
        altitudeMeters: 0,
        timestamp: day,
        isMocked: false,
      );

      expect(
        () => dataSource.insertSample(orphan),
        throwsA(isA<CacheException>()),
      );
    });

    test('re-inserting the same id updates rather than duplicating', () async {
      await dataSource.insertSample(sample('ls-1'));
      await dataSource.insertSample(sample('ls-1', mocked: true));

      final samples = await dataSource.fetchSamples('r-1');
      expect(samples, hasLength(1));
      expect(samples.single.isMocked, isTrue);
    });
  });

  group('fraud flags', () {
    FraudFlagModel flag(String id, {String? stopId}) => FraudFlagModel(
          id: id,
          routeId: 'r-1',
          stopId: stopId,
          type: FraudFlagType.values.first,
          detail: 'mock provider detected',
          timestamp: day.add(const Duration(hours: 9)),
          blocked: true,
        );

    test('a flag round-trips, including its enum type and blocked state',
        () async {
      await dataSource.insertFraudFlag(flag('ff-1'));

      final stored = (await dataSource.fetchFraudFlags('r-1')).single;
      expect(stored.id, 'ff-1');
      expect(stored.type, FraudFlagType.values.first);
      expect(stored.detail, 'mock provider detected');
      expect(stored.blocked, isTrue);
      expect(stored.stopId, isNull);
    });

    test('an unknown route returns empty', () async {
      expect(await dataSource.fetchFraudFlags('ghost-route'), isEmpty);
    });
  });
}
