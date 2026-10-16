import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sync_result.dart';
import 'package:steelforce/features/depots/domain/usecases/add_depot_activity.dart';
import 'package:steelforce/features/depots/domain/usecases/add_depot_note.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_depot_activities.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_depot_notes.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_by_id.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_last_synced_at.dart';
import 'package:steelforce/features/depots/domain/usecases/hydrate_depot.dart';
import 'package:steelforce/features/depots/domain/usecases/record_depot_viewed.dart';
import 'package:steelforce/features/depots/domain/usecases/run_depot_delta_sync.dart';
import 'package:steelforce/features/depots/domain/usecases/run_depot_initial_sync.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_state.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockRunInitial extends Mock implements RunDepotInitialSync {}

class _MockRunDelta extends Mock implements RunDepotDeltaSync {}

class _MockLastSynced extends Mock implements GetDepotLastSyncedAt {}

class _MockSession extends Mock implements SessionManager {}

class _MockLogger extends Mock implements AppLogger {}

class _MockGetById extends Mock implements GetDepotById {}

class _MockHydrate extends Mock implements HydrateDepot {}

class _MockNotes extends Mock implements FetchDepotNotes {}

class _MockAddNote extends Mock implements AddDepotNote {}

class _MockActivities extends Mock implements FetchDepotActivities {}

class _MockAddActivity extends Mock implements AddDepotActivity {}

class _MockViewed extends Mock implements RecordDepotViewed {}

class _FakeDepot extends Mock implements Depot {}

/// Online-first reads for the depot directory: every open asks the API, and
/// the local copy is only what shows when the API cannot answer.
void main() {
  final syncedAt = DateTime.utc(2026, 9, 30);
  final result = DepotSyncResult(upserted: 2, deleted: 0, syncedAt: syncedAt);

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const DepotIdParams('d'));
  });

  group('DepotSyncCubit.syncIfNeeded', () {
    late _MockRunInitial initial;
    late _MockRunDelta delta;
    late _MockLastSynced lastSynced;
    late _MockSession session;

    setUp(() {
      initial = _MockRunInitial();
      delta = _MockRunDelta();
      lastSynced = _MockLastSynced();
      session = _MockSession();
      when(() => session.canCallProtectedApi).thenReturn(true);
      when(() => session.hasAnyPermission(any())).thenReturn(true);
      when(() => initial(any())).thenAnswer((_) async => Success(result));
      when(() => delta(any())).thenAnswer((_) async => Success(result));
    });

    DepotSyncCubit build() => DepotSyncCubit(
          runInitialSync: initial,
          runDeltaSync: delta,
          getLastSyncedAt: lastSynced,
          session: session,
          logger: _MockLogger(),
        );

    test('pulls a delta on every open once synced — it used to stop forever',
        () async {
      when(() => lastSynced(any())).thenAnswer((_) async => Success(syncedAt));
      final cubit = build();

      await cubit.syncIfNeeded();
      await cubit.syncIfNeeded();

      verify(() => delta(any())).called(2);
      verifyNever(() => initial(any()));
      await cubit.close();
    });

    test('pulls the full directory when nothing has been synced', () async {
      when(() => lastSynced(any()))
          .thenAnswer((_) async => const Success<DateTime?>(null));
      final cubit = build();

      await cubit.syncIfNeeded();

      verify(() => initial(any())).called(1);
      await cubit.close();
    });

    test('overlapping opens share one pull', () async {
      when(() => lastSynced(any())).thenAnswer((_) async => Success(syncedAt));
      final cubit = build();

      await Future.wait([cubit.syncIfNeeded(), cubit.syncIfNeeded()]);

      verify(() => delta(any())).called(1);
      await cubit.close();
    });
  });

  group('DepotDetailCubit.load', () {
    late _MockGetById getById;
    late _MockHydrate hydrate;
    late _MockNotes notes;
    late _MockActivities activities;
    late _MockViewed viewed;
    final depot = _FakeDepot();

    setUp(() {
      getById = _MockGetById();
      hydrate = _MockHydrate();
      notes = _MockNotes();
      activities = _MockActivities();
      viewed = _MockViewed();
      when(() => viewed(any())).thenAnswer((_) async => const Success(null));
      when(() => getById(any())).thenAnswer((_) async => Success(depot));
      when(() => notes(any())).thenAnswer((_) async => const Success([]));
      when(() => activities(any())).thenAnswer((_) async => const Success([]));
    });

    DepotDetailCubit build() => DepotDetailCubit(
          getDepotById: getById,
          hydrateDepot: hydrate,
          fetchDepotNotes: notes,
          addDepotNote: _MockAddNote(),
          fetchDepotActivities: activities,
          addDepotActivity: _MockAddActivity(),
          recordDepotViewed: viewed,
        );

    test('refreshes the depot from the API before reading it', () async {
      when(() => hydrate(any())).thenAnswer((_) async => const Success(null));
      final cubit = build();

      await cubit.load('d1');

      verifyInOrder([
        () => hydrate(const DepotIdParams('d1')),
        () => getById(const DepotIdParams('d1')),
      ]);
      expect(cubit.state, isA<DepotDetailLoaded>());
      await cubit.close();
    });

    test('offline, still renders the local copy', () async {
      when(() => hydrate(any())).thenAnswer(
          (_) async => const Failed(NetworkFailure(message: 'offline')));
      final cubit = build();

      await cubit.load('d1');

      expect(cubit.state, isA<DepotDetailLoaded>());
      await cubit.close();
    });
  });
}
