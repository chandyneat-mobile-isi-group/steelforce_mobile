import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/services/location_tracking_service.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_location_sample.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';

/// `LocationTrackingState.current` was permanently null: nothing in the app
/// ever called `start`, and there was no screen-scoped alternative. Every
/// consumer that asks "where is the rep" — the check-in verification, the
/// geofence verdict, the nearest-first sort — was reading an empty value and
/// silently degrading.
class _FakeService implements LocationTrackingService {
  final _observed = StreamController<LocationSample>.broadcast();
  bool permission = true;
  int observeCalls = 0;
  int stopObserveCalls = 0;
  int? lastFilter;

  @override
  Future<bool> ensurePermission({bool background = false}) async => permission;

  @override
  Stream<LocationSample> observe({int distanceFilterMeters = 25}) {
    observeCalls++;
    lastFilter = distanceFilterMeters;
    return _observed.stream;
  }

  @override
  Future<void> stopObserving() async => stopObserveCalls++;

  @override
  Stream<LocationSample> track(String routeId) => const Stream.empty();

  @override
  Future<void> stop() async {}

  void emit(LocationSample s) => _observed.add(s);
  Future<void> dispose() => _observed.close();
}

class _NoopRepo implements LocationSampleRepository {
  final List<LocationSample> recorded = [];
  @override
  ResultFuture<void> recordSample(LocationSample sample) async {
    recorded.add(sample);
    return const Success(null);
  }

  @override
  ResultFuture<void> recordFraudFlag(FraudFlag flag) async =>
      const Success(null);
  @override
  ResultFuture<List<LocationSample>> fetchSamples(String routeId) async =>
      const Success([]);
  @override
  ResultFuture<List<FraudFlag>> fetchFraudFlags(String routeId) async =>
      const Success([]);
}

LocationSample sampleAt(double lat, double lng) => LocationSample(
      id: '$lat-$lng',
      routeId: 'route-1',
      latitude: lat,
      longitude: lng,
      accuracyMeters: 8,
      speedMps: 0,
      headingDegrees: 0,
      altitudeMeters: 0,
      timestamp: DateTime.now(),
      isMocked: false,
    );

void main() {
  late _FakeService service;
  late _NoopRepo repo;
  late LocationTrackingCubit cubit;

  setUp(() {
    service = _FakeService();
    repo = _NoopRepo();
    cubit = LocationTrackingCubit(
      trackingService: service,
      recordLocationSample: RecordLocationSample(repo),
      recordFraudFlag: RecordFraudFlag(repo),
      fraudDetectionService: const FraudDetectionService(),
    );
  });
  tearDown(() async {
    await cubit.close();
    await service.dispose();
  });

  test('current is null until something starts the GPS', () {
    // The bug in one line: this was the app's permanent state.
    expect(cubit.state.current, isNull);
    expect(service.observeCalls, 0);
  });

  test('observeForScreen publishes live positions', () async {
    await cubit.observeForScreen();
    service.emit(sampleAt(11.5564, 104.9282));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.current, isNotNull);
    expect(cubit.state.current!.latitude, 11.5564);
  });

  test('honours the caller’s distance filter', () async {
    await cubit.observeForScreen(distanceFilterMeters: 10);
    // The check-in radius is 100 m; the 25 m default would hold a stale
    // reading exactly where the rep needs it moving.
    expect(service.lastFilter, 10);
  });

  test('does not persist screen-scoped samples', () async {
    await cubit.observeForScreen();
    service.emit(sampleAt(11.5564, 104.9282));
    await Future<void>.delayed(Duration.zero);

    // A live reading for the UI, not the audit trail — that is `start`'s job.
    expect(repo.recorded, isEmpty);
  });

  test('calling it twice replaces rather than stacks', () async {
    await cubit.observeForScreen();
    await cubit.observeForScreen();

    expect(service.observeCalls, 2);
    service.emit(sampleAt(11.60, 104.90));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.current!.latitude, 11.60);
  });

  test('a refused permission is reported, not swallowed', () async {
    service.permission = false;

    final ok = await cubit.observeForScreen();

    expect(ok, isFalse);
    expect(cubit.state.permissionDenied, isTrue);
    expect(cubit.state.current, isNull);
  });

  test('stopObserving releases the stream', () async {
    await cubit.observeForScreen();
    await cubit.stopObserving();

    expect(service.stopObserveCalls, 1);
  });
}
