import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/sync_result.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/count_products.dart';
import 'package:steelforce/features/order/domain/usecases/get_last_synced_at.dart';
import 'package:steelforce/features/order/domain/usecases/run_delta_sync.dart';
import 'package:steelforce/features/order/domain/usecases/run_initial_sync.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_state.dart';
import 'package:mocktail/mocktail.dart';

class _Initial extends Mock implements RunInitialSync {}

class _Delta extends Mock implements RunDeltaSync {}

class _LastSynced extends Mock implements GetLastSyncedAt {}

class _Count extends Mock implements CountProducts {}

void main() {
  late _Initial initial;
  late _Delta delta;
  late _LastSynced lastSynced;
  late _Count count;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const BrowseProductsParams(page: 0, pageSize: 1));
    registerFallbackValue(SyncScope.forCurrentUser(SessionManager()));
  });

  setUp(() {
    initial = _Initial();
    delta = _Delta();
    lastSynced = _LastSynced();
    count = _Count();
  });

  SyncCubit build() => SyncCubit(
        runInitialSync: initial,
        runDeltaSync: delta,
        getLastSyncedAt: lastSynced,
        countProducts: count,
        sessionManager: SessionManager(),
      );

  void haveCatalog() {
    when(() => lastSynced(any()))
        .thenAnswer((_) async => Success(DateTime(2026, 9, 1)));
    when(() => count(any())).thenAnswer((_) async => const Success(120));
  }

  test('a device with a catalog still asks the API what changed', () async {
    haveCatalog();
    when(() => delta(any())).thenAnswer((_) async => Success(
        SyncResult(upserted: 3, deleted: 0, syncedAt: DateTime(2026, 10))));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.syncIfNeeded();

    verify(() => delta(any())).called(1);
    verifyNever(() => initial(any()));
    expect(cubit.state, isA<SyncSucceeded>());
    expect((cubit.state as SyncSucceeded).changedAnything, isTrue);
  });

  test('an empty device (after sign-out) downloads the whole catalog',
      () async {
    when(() => lastSynced(any())).thenAnswer((_) async => const Success(null));
    when(() => initial(any())).thenAnswer((_) async => Success(
        SyncResult(upserted: 500, deleted: 0, syncedAt: DateTime(2026, 10))));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.syncIfNeeded();

    verify(() => initial(any())).called(1);
    verifyNever(() => delta(any()));
  });

  test('offline, the local catalog is used without an error banner', () async {
    haveCatalog();
    when(() => delta(any()))
        .thenAnswer((_) async => const Failed(NetworkFailure()));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.syncIfNeeded();

    expect(cubit.state, isA<SyncIdle>());
  });

  test('a server error on that pull is still reported', () async {
    haveCatalog();
    when(() => delta(any()))
        .thenAnswer((_) async => const Failed(ServerFailure(message: 'boom')));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.syncIfNeeded();

    expect(cubit.state, isA<SyncFailed>());
  });
}
