import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sync_result.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_paged_result.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_last_synced_at.dart';
import 'package:steelforce/features/depots/domain/usecases/run_depot_initial_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_push_summary.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route_last_synced_at.dart';
import 'package:steelforce/features/my_visits/domain/usecases/push_pending_visit_data.dart';
import 'package:steelforce/features/my_visits/domain/usecases/run_route_delta_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/run_route_initial_sync.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/route_sync_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockRunRouteInitialSync extends Mock implements RunRouteInitialSync {}

class _MockRunRouteDeltaSync extends Mock implements RunRouteDeltaSync {}

class _MockGetRouteLastSyncedAt extends Mock implements GetRouteLastSyncedAt {}

class _MockPushPendingVisitData extends Mock implements PushPendingVisitData {}

class _MockRunDepotInitialSync extends Mock implements RunDepotInitialSync {}

class _MockGetDepotLastSyncedAt extends Mock implements GetDepotLastSyncedAt {}

class _MockBrowseDepots extends Mock implements BrowseDepots {}

/// Only its presence in the list matters — the gate asks "are there any rows",
/// never what is in them.
class _FakeDepot extends Mock implements Depot {}

class _MockSessionManager extends Mock implements SessionManager {}

void main() {
  // Fixed, UTC-anchored instant — RouteSyncSucceeded equality includes
  // syncedAt, and visit dates in this feature are UTC-anchored by convention.
  final syncedAt = DateTime.utc(2026, 7, 22, 3);
  final routeResult =
      RouteSyncResult(upserted: 3, deleted: 0, syncedAt: syncedAt);
  final depotResult =
      DepotSyncResult(upserted: 6, deleted: 0, syncedAt: syncedAt);

  late _MockRunRouteInitialSync runRouteInitialSync;
  late _MockRunRouteDeltaSync runRouteDeltaSync;
  late _MockGetRouteLastSyncedAt getRouteLastSyncedAt;
  late _MockPushPendingVisitData pushPendingVisitData;
  late _MockRunDepotInitialSync runDepotInitialSync;
  late _MockGetDepotLastSyncedAt getDepotLastSyncedAt;
  late _MockBrowseDepots browseDepots;
  late _MockSessionManager sessionManager;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
        const RouteSyncScope(repId: 'guest', territory: 'Phnom Penh'));
    registerFallbackValue(const BrowseDepotsParams(page: 0, pageSize: 1));
  });

  setUp(() {
    runRouteInitialSync = _MockRunRouteInitialSync();
    runRouteDeltaSync = _MockRunRouteDeltaSync();
    getRouteLastSyncedAt = _MockGetRouteLastSyncedAt();
    pushPendingVisitData = _MockPushPendingVisitData();
    runDepotInitialSync = _MockRunDepotInitialSync();
    getDepotLastSyncedAt = _MockGetDepotLastSyncedAt();
    browseDepots = _MockBrowseDepots();
    // Default: the directory has rows. Tests that care override this.
    when(() => browseDepots(any())).thenAnswer((_) async => Success(
        DepotPagedResult(items: [_FakeDepot()], page: 0, hasMore: false)));
    sessionManager = _MockSessionManager();
    when(() => sessionManager.currentUser).thenReturn(null);
  });

  RouteSyncCubit buildCubit() => RouteSyncCubit(
        runInitialSync: runRouteInitialSync,
        runDeltaSync: runRouteDeltaSync,
        getLastSyncedAt: getRouteLastSyncedAt,
        pushPendingVisitData: pushPendingVisitData,
        runDepotInitialSync: runDepotInitialSync,
        getDepotLastSyncedAt: getDepotLastSyncedAt,
        browseDepots: browseDepots,
        sessionManager: sessionManager,
      );

  // ── Stub helpers so each test reads as its scenario ─────────────────
  void depotsAlreadySynced() => when(() => getDepotLastSyncedAt(any()))
      .thenAnswer((_) async => Success(syncedAt));

  void depotsNeverSynced() => when(() => getDepotLastSyncedAt(any()))
      .thenAnswer((_) async => const Success<DateTime?>(null));

  void routesNeverSynced() => when(() => getRouteLastSyncedAt(any()))
      .thenAnswer((_) async => const Success<DateTime?>(null));

  void routesPreviouslySynced() => when(() => getRouteLastSyncedAt(any()))
      .thenAnswer((_) async => Success(syncedAt));

  void routeInitialSucceeds() => when(() => runRouteInitialSync(any()))
      .thenAnswer((_) async => Success(routeResult));

  void routeDeltaSucceeds() => when(() => runRouteDeltaSync(any()))
      .thenAnswer((_) async => Success(routeResult));

  void depotInitialSucceeds() => when(() => runDepotInitialSync(any()))
      .thenAnswer((_) async => Success(depotResult));

  void depotDirectoryEmpty() =>
      when(() => browseDepots(any())).thenAnswer((_) async =>
          const Success(DepotPagedResult(items: [], page: 0, hasMore: false)));

  group('syncIfNeeded', () {
    blocTest<RouteSyncCubit, RouteSyncState>(
      'pulls depots when the watermark says synced but the table is empty',
      build: buildCubit,
      setUp: () {
        // The state behind the empty Visit dashboards: a depot watermark
        // left by an earlier build over a directory that is actually empty.
        // Skipping the pull here left the route feed — which rebases stops
        // onto real depot ids — with nothing to rebase onto, so every
        // Visit screen came up blank.
        depotsAlreadySynced();
        depotDirectoryEmpty();
        depotInitialSucceeds();
        routesPreviouslySynced();
        routeDeltaSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      verify: (_) {
        verify(() => runDepotInitialSync(any())).called(1);
        verify(() => runRouteDeltaSync(any())).called(1);
      },
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'skips the depot pull when the directory is genuinely populated',
      build: buildCubit,
      setUp: () {
        depotsAlreadySynced();
        routesPreviouslySynced();
        routeDeltaSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      verify: (_) => verifyNever(() => runDepotInitialSync(any())),
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'runs an initial route sync when there is no route watermark',
      build: buildCubit,
      setUp: () {
        routesNeverSynced();
        depotsAlreadySynced();
        routeInitialSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      expect: () => [
        const RouteSyncInProgress(isInitial: true),
        RouteSyncSucceeded(upserted: 3, syncedAt: syncedAt),
      ],
      verify: (_) {
        verify(() => runRouteInitialSync(any())).called(1);
        verifyNever(() => runRouteDeltaSync(any()));
      },
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'runs a delta sync when a route watermark exists',
      build: buildCubit,
      setUp: () {
        routesPreviouslySynced();
        depotsAlreadySynced();
        routeDeltaSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      expect: () => [
        const RouteSyncInProgress(isInitial: false),
        RouteSyncSucceeded(upserted: 3, syncedAt: syncedAt),
      ],
      verify: (_) {
        verify(() => runRouteDeltaSync(any())).called(1);
        verifyNever(() => runRouteInitialSync(any()));
      },
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'falls back to an initial sync when the route watermark read fails',
      build: buildCubit,
      setUp: () {
        when(() => getRouteLastSyncedAt(any())).thenAnswer(
            (_) async => const Failed(CacheFailure(message: 'db closed')));
        depotsAlreadySynced();
        routeInitialSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      expect: () => [
        const RouteSyncInProgress(isInitial: true),
        RouteSyncSucceeded(upserted: 3, syncedAt: syncedAt),
      ],
      verify: (_) => verify(() => runRouteInitialSync(any())).called(1),
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'surfaces a route sync failure as RouteSyncFailed',
      build: buildCubit,
      setUp: () {
        routesNeverSynced();
        depotsAlreadySynced();
        when(() => runRouteInitialSync(any())).thenAnswer((_) async =>
            const Failed(ServerFailure(message: 'boom', statusCode: 500)));
      },
      act: (cubit) => cubit.syncIfNeeded(),
      expect: () => [
        const RouteSyncInProgress(isInitial: true),
        const RouteSyncFailed('boom'),
      ],
    );
  });

  group('depot-directory ordering guard (ADR-001 FK dependency)', () {
    blocTest<RouteSyncCubit, RouteSyncState>(
      'skips depot sync entirely once the depot watermark exists',
      build: buildCubit,
      setUp: () {
        routesNeverSynced();
        depotsAlreadySynced();
        routeInitialSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      verify: (_) => verifyNever(() => runDepotInitialSync(any())),
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'fresh install: awaits depot initial sync before the route pull',
      build: buildCubit,
      setUp: () {
        routesNeverSynced();
        depotsNeverSynced();
        depotInitialSucceeds();
        routeInitialSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      expect: () => [
        const RouteSyncInProgress(isInitial: true),
        RouteSyncSucceeded(upserted: 3, syncedAt: syncedAt),
      ],
      verify: (_) => verifyInOrder([
        () => runDepotInitialSync(any()),
        () => runRouteInitialSync(any()),
      ]),
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'fails fast when depot sync fails — no route pull is attempted',
      build: buildCubit,
      setUp: () {
        routesNeverSynced();
        depotsNeverSynced();
        when(() => runDepotInitialSync(any()))
            .thenAnswer((_) async => const Failed(NetworkFailure()));
      },
      act: (cubit) => cubit.syncIfNeeded(),
      expect: () => [
        const RouteSyncInProgress(isInitial: true),
        const RouteSyncFailed('No internet connection.'),
      ],
      verify: (_) {
        verifyNever(() => runRouteInitialSync(any()));
        verifyNever(() => runRouteDeltaSync(any()));
      },
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'treats a depot watermark read failure as needing depot sync',
      build: buildCubit,
      setUp: () {
        routesNeverSynced();
        when(() => getDepotLastSyncedAt(any())).thenAnswer(
            (_) async => const Failed(CacheFailure(message: 'db closed')));
        depotInitialSucceeds();
        routeInitialSucceeds();
      },
      act: (cubit) => cubit.syncIfNeeded(),
      expect: () => [
        const RouteSyncInProgress(isInitial: true),
        RouteSyncSucceeded(upserted: 3, syncedAt: syncedAt),
      ],
      verify: (_) => verify(() => runDepotInitialSync(any())).called(1),
    );
  });

  group('refresh', () {
    blocTest<RouteSyncCubit, RouteSyncState>(
      'always runs a delta sync, still behind the depot guard',
      build: buildCubit,
      setUp: () {
        depotsAlreadySynced();
        routeDeltaSucceeds();
      },
      act: (cubit) => cubit.refresh(),
      expect: () => [
        const RouteSyncInProgress(isInitial: false),
        RouteSyncSucceeded(upserted: 3, syncedAt: syncedAt),
      ],
      verify: (_) {
        verify(() => getDepotLastSyncedAt(any())).called(1);
        verifyNever(() => runRouteInitialSync(any()));
      },
    );
  });

  group('pushPending', () {
    blocTest<RouteSyncCubit, RouteSyncState>(
      'reports pushed rows as a sync success',
      build: buildCubit,
      setUp: () => when(() => pushPendingVisitData(any())).thenAnswer(
          (_) async =>
              Success(VisitPushSummary(pushedCount: 4, syncedAt: syncedAt))),
      act: (cubit) => cubit.pushPending(),
      expect: () => [
        const RouteSyncInProgress(isInitial: false),
        RouteSyncSucceeded(upserted: 4, syncedAt: syncedAt),
      ],
    );

    blocTest<RouteSyncCubit, RouteSyncState>(
      'surfaces a push failure as RouteSyncFailed',
      build: buildCubit,
      setUp: () => when(() => pushPendingVisitData(any())).thenAnswer(
          (_) async => const Failed(ServerFailure(message: 'push rejected'))),
      act: (cubit) => cubit.pushPending(),
      expect: () => [
        const RouteSyncInProgress(isInitial: false),
        const RouteSyncFailed('push rejected'),
      ],
    );
  });

  group('online-first', () {
    test('overlapping opens share one pull instead of stacking two', () async {
      // The tab now re-pulls every time it is shown, and the Home badge
      // pulls too; a rep flicking between tabs must not start parallel page
      // loops against the route feed.
      depotsAlreadySynced();
      routesPreviouslySynced();
      routeDeltaSucceeds();
      final cubit = buildCubit();

      await Future.wait([cubit.syncIfNeeded(), cubit.syncIfNeeded()]);

      verify(() => runRouteDeltaSync(any())).called(1);
      await cubit.close();
    });

    test('a later open pulls again rather than trusting the last sync',
        () async {
      depotsAlreadySynced();
      routesPreviouslySynced();
      routeDeltaSucceeds();
      final cubit = buildCubit();

      await cubit.syncIfNeeded();
      await cubit.syncIfNeeded();

      verify(() => runRouteDeltaSync(any())).called(2);
      await cubit.close();
    });
  });
}
