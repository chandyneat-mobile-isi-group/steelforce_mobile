import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stop_discard.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/discard_pending_visit_stop.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';

class _Offline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

class _NoRemote implements VisitSyncRemoteDataSource {
  @override
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch) =>
      throw StateError('no request may be made');
}

class _MockRouteRepository extends Mock implements RouteRepository {}

class _MockVisitSyncRepository extends Mock implements VisitSyncRepository {}

/// The Sync Center's per-stop view of unsent visit work, and the discard.
void main() {
  late AppDatabase db;
  late VisitDriftLocalDataSource local;
  late List<String> deletedFiles;
  late VisitSyncRepositoryImpl repo;

  const logger = ConsoleAppLogger(verbose: false);
  final morning = DateTime.utc(2026, 10, 5, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = VisitDriftLocalDataSource(db.visitDao, logger);
    deletedFiles = [];
    repo = VisitSyncRepositoryImpl(
      remote: _NoRemote(),
      local: local,
      network: _Offline(),
      logger: logger,
      deleteFile: deletedFiles.add,
    );
  });

  tearDown(() => db.close());

  CheckInRecordModel checkIn(String stop, int hour) => CheckInRecordModel(
        id: 'ci-$stop',
        stopId: stop,
        timestamp: morning.add(Duration(hours: hour)),
        latitude: 11.55,
        longitude: 104.91,
        accuracyMeters: 8,
        distanceFromDepotMeters: 20,
        isMocked: false,
      );

  CheckOutRecordModel checkOut(String stop, int hour) => CheckOutRecordModel(
        id: 'co-$stop',
        stopId: stop,
        timestamp: morning.add(Duration(hours: hour, minutes: 30)),
        latitude: 11.55,
        longitude: 104.91,
        durationMinutes: 30,
        visitSummary: 'done',
      );

  VisitStockUpdateModel stock(String id, {String? stopId, String? depotId}) =>
      VisitStockUpdateModel(
        id: id,
        stopId: stopId,
        depotId: depotId,
        productId: 'P-10',
        productName: 'Rebar',
        stockLevel: StockLevel.low,
        notes: '',
      );

  VisitPhotoModel photo(String id, String stop, int hour) => VisitPhotoModel(
        id: id,
        stopId: stop,
        url: '/data/$id.jpg',
        caption: '',
        takenAt: morning.add(Duration(hours: hour)),
      );

  VisitNoteModel note(String id, String stop, int hour) => VisitNoteModel(
        id: id,
        stopId: stop,
        type: VisitNoteType.general,
        text: 'note',
        createdAt: morning.add(Duration(hours: hour)),
      );

  PendingVisitSync read(Result<PendingVisitSync> r) =>
      (r as Success<PendingVisitSync>).data;

  group('fetchPendingVisits', () {
    test(
        'a stop whose only unsent rows are captures is its own entry, with '
        'counts by kind', () async {
      // s-1: check-in + check-out already synced; only captures left.
      await local.insertCheckIn(checkIn('s-1', 1));
      await local.insertCheckOut(checkOut('s-1', 1));
      await local.markSynced(table: 'checkins', ids: ['ci-s-1']);
      await local.markSynced(table: 'checkouts', ids: ['co-s-1']);
      await local.insertStockUpdate(stock('su-1', stopId: 's-1'));
      await local.insertStockUpdate(stock('su-2', stopId: 's-1'));
      await local.insertNote(note('no-1', 's-1', 1));
      await local.insertPhoto(photo('ph-1', 's-1', 1));

      final pending = read(await repo.fetchPendingVisits());

      expect(pending.stops, hasLength(1));
      final s = pending.stops.single;
      expect(s.stopId, 's-1');
      expect(s.checkInAt, isNull);
      expect(s.checkOutAt, isNull);
      expect(s.stockUpdates, 2);
      expect(s.notes, 1);
      expect(s.photos, 1);
      expect(s.captureCount, 4);
      expect(s.recordCount, 4);
      expect(pending.otherRecords, 0);
    });

    test(
        'stops are oldest first; a stop with nothing timed goes last; a '
        'stopless stock count is the only "other" record', () async {
      await local.insertCheckIn(checkIn('s-late', 5));
      await local.insertCheckIn(checkIn('s-early', 2));
      await local.insertCheckOut(checkOut('s-early', 2));
      await local.insertOrderLine(const VisitOrderLineModel(
        id: 'ol-1',
        stopId: 's-untimed',
        productId: 'P',
        productName: 'Rebar',
        quantity: 1,
        unit: 'pcs',
        unitPrice: 4,
      ));
      await local.insertStockUpdate(stock('su-depot', depotId: 'd-9'));

      final pending = read(await repo.fetchPendingVisits());

      expect(pending.stops.map((s) => s.stopId),
          ['s-early', 's-late', 's-untimed']);
      expect(pending.stops[0].checkOutWaitsForCheckIn, isTrue);
      expect(pending.stops[2].orderLines, 1);
      expect(pending.otherRecords, 1);

      // Stops plus "other" add up to the figure the sign-out guard uses.
      final rows = pending.stops.fold<int>(0, (n, s) => n + s.recordCount) +
          pending.otherRecords;
      expect(rows, await local.countPendingVisitRecords());
    });
  });

  group('discardPendingStop', () {
    test(
        'removes the stop\'s unsent rows, then deletes its photo files and '
        'reports how the stop was reset', () async {
      await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
            id: 's-1',
            routeId: 'r-1',
            depotId: 'd-1',
            sequence: 1,
            status: 'checkedIn',
            actualArrival: Value(morning),
          ));
      await local.insertCheckIn(checkIn('s-1', 1));
      await local.insertPhoto(photo('ph-1', 's-1', 1));
      await local.insertNote(note('no-1', 's-1', 1));
      await local.insertCheckIn(checkIn('s-2', 2));

      final result = await repo.discardPendingStop('s-1');

      final discard = (result as Success<VisitStopDiscard>).data;
      expect(discard.reset, VisitStopReset.notVisited);
      expect(discard.discardedRecords, 3);
      expect(deletedFiles, ['/data/ph-1.jpg']);
      final pending = read(await repo.fetchPendingVisits());
      expect(pending.stops.map((s) => s.stopId), ['s-2']);
      final stop = await (db.select(db.routeStops)
            ..where((t) => t.id.equals('s-1')))
          .getSingle();
      expect(stop.status, 'pending');
      expect(stop.actualArrival, isNull);
      expect(stop.syncState, SyncStates.synced);
    });

    test('a file that will not delete does not fail the discard', () async {
      repo = VisitSyncRepositoryImpl(
        remote: _NoRemote(),
        local: local,
        network: _Offline(),
        deleteFile: (_) => throw StateError('disk'),
      );
      await local.insertPhoto(photo('ph-1', 's-1', 1));

      final result = await repo.discardPendingStop('s-1');

      expect(result, isA<Success<VisitStopDiscard>>());
      expect(await local.countPendingVisitRecords(), 0);
    });

    test('a storage failure maps to a CacheFailure, nothing deleted', () async {
      await local.insertPhoto(photo('ph-1', 's-1', 1));
      await db.close();

      final result = await repo.discardPendingStop('s-1');

      expect(result, isA<Failed<VisitStopDiscard>>());
      expect((result as Failed).failure, isA<CacheFailure>());
      expect(deletedFiles, isEmpty);
      // Reopen so tearDown's close has something to close.
      db = AppDatabase(NativeDatabase.memory());
    });
  });

  group('DiscardPendingVisitStop', () {
    late _MockVisitSyncRepository visitSync;
    late _MockRouteRepository routes;

    setUp(() {
      visitSync = _MockVisitSyncRepository();
      routes = _MockRouteRepository();
      when(routes.notifyStopsChanged).thenAnswer((_) async {});
    });

    test('tells open stop lists when the stop was reset', () async {
      when(() => visitSync.discardPendingStop('s-1')).thenAnswer((_) async =>
          const Success(VisitStopDiscard(
              stopId: 's-1',
              discardedRecords: 2,
              reset: VisitStopReset.notVisited)));

      await DiscardPendingVisitStop(visitSync, routes)(
          const StopIdParams('s-1'));

      verify(routes.notifyStopsChanged).called(1);
    });

    test('does not when only captures went, nor on failure', () async {
      when(() => visitSync.discardPendingStop('s-1')).thenAnswer((_) async =>
          const Success(VisitStopDiscard(
              stopId: 's-1',
              discardedRecords: 2,
              reset: VisitStopReset.unchanged)));
      when(() => visitSync.discardPendingStop('s-2'))
          .thenAnswer((_) async => const Failed(CacheFailure(message: 'x')));

      final usecase = DiscardPendingVisitStop(visitSync, routes);
      await usecase(const StopIdParams('s-1'));
      final failed = await usecase(const StopIdParams('s-2'));

      expect(failed, isA<Failed<VisitStopDiscard>>());
      verifyNever(routes.notifyStopsChanged);
    });
  });
}
