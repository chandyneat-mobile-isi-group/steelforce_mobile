import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/daos/visit_dao.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/remote/route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/route_sync_page.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_sync_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Regression cover for a crash that reached a real device.
///
/// `ApiException` is a *sibling* of `ServerException`, not a subtype, and the
/// API data sources throw it exclusively. Both sync repositories caught only
/// `ServerException`/`CacheException`, so an expired session threw straight
/// through the repository, past the cubit, and out as an uncaught zone error —
/// the app went down on a 401 that should have been a SnackBar.
///
/// It stayed hidden because the fixture sources these replaced happened to
/// throw `ServerException`, so every repository test passed while the live
/// path was broken. These tests assert the *repository* converts, rather than
/// asserting the data source throws.
class _AlwaysOnline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

const _unauthorized = ApiException(ApiError(
  code: ApiErrorCodes.notAuthenticated,
  message: 'Unauthorized.',
  statusCode: 401,
  correlationId: '0HN:1',
));

const _offline = ApiException(ApiError(code: ApiErrorCodes.network));

const _serverError = ApiException(ApiError(
  code: 'Visit.StopNotFound',
  message: 'Not found.',
  statusCode: 404,
));

/// Throws whatever it is handed, on every call.
class _ThrowingRouteRemote implements RouteRemoteDataSource {
  _ThrowingRouteRemote(this.error);
  final Object error;

  @override
  Future<RouteSyncPage> fetchInitial(
          {required RouteSyncScope scope,
          required int page,
          required int pageSize}) async =>
      throw error;

  @override
  Future<RouteSyncPage> fetchDelta(
          {required RouteSyncScope scope, required DateTime since}) async =>
      throw error;
}

class _ThrowingVisitSyncRemote implements VisitSyncRemoteDataSource {
  _ThrowingVisitSyncRemote(this.error);
  final Object error;

  @override
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch) async =>
      throw error;
}

/// Minimal local source: enough to satisfy the repositories' reads and to
/// record whether anything was ever marked synced.
class _FakeRouteLocal implements RouteLocalDataSource {
  DateTime? watermark;
  bool upserted = false;

  @override
  Future<DateTime?> getLastSyncedAt(String entity) async => watermark;

  @override
  Future<void> setLastSyncedAt(String entity, DateTime at) async =>
      watermark = at;

  @override
  Future<void> upsertDepots(List<DepotStopInfoModel> depots) async =>
      upserted = true;

  @override
  Future<void> upsertRoutes(List<RoutePlanModel> routes) async =>
      upserted = true;

  @override
  Future<List<RoutePlanModel>> fetchTodayRoutes() async => const [];
  @override
  Future<List<RoutePlanModel>> fetchAllRoutes() async => const [];
  @override
  Future<RoutePlanModel?> getRoute(String routeId) async => null;
  @override
  Future<void> updateRouteStatus(String routeId, RouteStatus status) async {}
  @override
  Future<void> updateStopStatus(String stopId,
      {required VisitStatus status,
      DateTime? actualArrival,
      DateTime? actualDeparture}) async {}
}

class _FakeVisitLocal implements VisitLocalDataSource {
  /// Every id this source was told to mark synced. Must stay empty on failure.
  final List<String> markedSynced = [];

  @override
  Future<void> markSynced(
          {required String table, required List<String> ids}) async =>
      markedSynced.addAll(ids);

  @override
  Future<List<CheckInRecordModel>> fetchPendingCheckIns() async => [
        CheckInRecordModel(
          id: 'ci-1',
          stopId: 'stop-1',
          timestamp: DateTime.utc(2026, 8, 20, 9),
          latitude: 11.55,
          longitude: 104.91,
          accuracyMeters: 8,
          distanceFromDepotMeters: 20,
          isMocked: false,
        )
      ];

  @override
  Future<List<CheckOutRecordModel>> fetchPendingCheckOuts() async => const [];
  @override
  Future<List<VisitOrderLineModel>> fetchPendingOrderLines() async => const [];
  @override
  Future<List<VisitStockUpdateModel>> fetchPendingStockUpdates() async =>
      const [];
  @override
  Future<List<VisitReturnModel>> fetchPendingReturns() async => const [];
  @override
  Future<List<VisitCollectionModel>> fetchPendingCollections() async =>
      const [];
  @override
  Future<List<VisitNoteModel>> fetchPendingNotes() async => const [];
  @override
  Future<List<VisitPhotoModel>> fetchPendingPhotos() async => const [];

  @override
  Future<int> countPendingVisitRecords() async => 1;

  @override
  Future<int> countPendingCheckIns() async => 1;

  @override
  Future<int> countPendingCheckOuts() async => 0;

  @override
  Future<CheckInRecordModel?> checkInForStop(String stopId) async => null;
  @override
  Future<void> adoptServerCheckIn(String localId, String serverId) async {}
  @override
  Future<void> deleteCheckIn(String id) async {}
  @override
  Future<void> deleteCheckOut(String id) async {}

  @override
  Future<Map<String, ({String name, String nameKh})>> fetchShopNamesForStops(
          Set<String> stopIds) async =>
      const {};

  @override
  Future<DiscardedStopWork> discardUnsentStopWork(String stopId) async =>
      const DiscardedStopWork(
          rowsDeleted: 0, reset: StopResetKind.unchanged, photoPaths: []);

  @override
  Future<void> insertCheckIn(CheckInRecordModel record) async {}
  @override
  Future<void> insertCheckOut(CheckOutRecordModel record) async {}
  @override
  Future<void> insertOrderLine(VisitOrderLineModel line) async {}
  @override
  Future<void> insertStockUpdate(VisitStockUpdateModel update) async {}
  @override
  Future<void> insertReturn(VisitReturnModel returnItem) async {}
  @override
  Future<void> insertCollection(VisitCollectionModel collection) async {}
  @override
  Future<void> insertNote(VisitNoteModel note) async {}
  @override
  Future<void> insertPhoto(VisitPhotoModel photo) async {}
  @override
  Future<List<VisitOrderLineModel>> fetchOrderLines(String stopId) async =>
      const [];
  @override
  Future<List<VisitStockUpdateModel>> fetchStockUpdates(String stopId) async =>
      const [];
  @override
  Future<List<VisitReturnModel>> fetchReturns(String stopId) async => const [];
  @override
  Future<List<VisitCollectionModel>> fetchCollections(String stopId) async =>
      const [];
  @override
  Future<List<VisitNoteModel>> fetchNotes(String stopId) async => const [];
  @override
  Future<List<VisitPhotoModel>> fetchPhotos(String stopId) async => const [];
}

void main() {
  const scope = RouteSyncScope(repId: 'rep-1', territory: 'PP-NORTH');

  group('RouteSyncRepositoryImpl converts ApiException', () {
    RouteSyncRepositoryImpl build(Object error, {DateTime? watermark}) =>
        RouteSyncRepositoryImpl(
          remote: _ThrowingRouteRemote(error),
          local: _FakeRouteLocal()..watermark = watermark,
          network: _AlwaysOnline(),
        );

    test('a 401 on the delta pull is returned, never thrown', () async {
      // The exact shape that crashed the app: a delta sync (watermark present)
      // whose 401 survived the interceptor's refresh attempt.
      final repo = build(_unauthorized, watermark: DateTime.utc(2026, 8, 19));

      final result = await repo.runDeltaSync(scope);

      expect(result.when(success: (_) => false, failure: (_) => true), isTrue);
      expect(
        result.when(success: (_) => null, failure: (f) => f),
        isA<AuthenticationFailure>(),
        reason: 'an unrecoverable 401 is an auth problem, not a route problem',
      );
    });

    test('a 401 on the initial pull is returned, never thrown', () async {
      final repo = build(_unauthorized);

      final result = await repo.runInitialSync(scope);

      expect(result.when(success: (_) => null, failure: (f) => f),
          isA<AuthenticationFailure>());
    });

    test('a transport failure maps to NetworkFailure', () async {
      final repo = build(_offline);

      final result = await repo.runInitialSync(scope);

      expect(result.when(success: (_) => null, failure: (f) => f),
          isA<NetworkFailure>());
    });

    test('any other API error maps to ServerFailure, keeping the status',
        () async {
      final repo = build(_serverError);

      final result = await repo.runInitialSync(scope);
      final failure = result.when(success: (_) => null, failure: (f) => f);

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 404);
    });

    test('the watermark is not advanced by a failed sync', () async {
      final local = _FakeRouteLocal();
      final repo = RouteSyncRepositoryImpl(
        remote: _ThrowingRouteRemote(_unauthorized),
        local: local,
        network: _AlwaysOnline(),
      );

      await repo.runInitialSync(scope);

      // Advancing it would silently skip whatever the failed pull missed.
      expect(local.watermark, isNull);
      expect(local.upserted, isFalse);
    });
  });

  group('VisitSyncRepositoryImpl converts ApiException', () {
    test('a 401 on push is returned, and nothing is marked synced', () async {
      final local = _FakeVisitLocal();
      final repo = VisitSyncRepositoryImpl(
        remote: _ThrowingVisitSyncRemote(_unauthorized),
        local: local,
        network: _AlwaysOnline(),
      );

      final result = await repo.pushPendingVisitData();

      expect(result.when(success: (_) => null, failure: (f) => f),
          isA<AuthenticationFailure>());
      // The whole point of the offline queue: a failed push costs a retry,
      // never a capture.
      expect(local.markedSynced, isEmpty);
    });

    test('a transport failure maps to NetworkFailure, rows still pending',
        () async {
      final local = _FakeVisitLocal();
      final repo = VisitSyncRepositoryImpl(
        remote: _ThrowingVisitSyncRemote(_offline),
        local: local,
        network: _AlwaysOnline(),
      );

      final result = await repo.pushPendingVisitData();

      expect(result.when(success: (_) => null, failure: (f) => f),
          isA<NetworkFailure>());
      expect(local.markedSynced, isEmpty);
    });
  });
}
