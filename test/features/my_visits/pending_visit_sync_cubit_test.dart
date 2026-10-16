import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stop_discard.dart';
import 'package:steelforce/features/my_visits/domain/usecases/discard_pending_visit_stop.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';

class _MockGet extends Mock implements GetPendingVisitSync {}

class _MockDiscard extends Mock implements DiscardPendingVisitStop {}

const _one = PendingVisitSync(stops: [PendingVisitStop(stopId: 's-1')]);

void main() {
  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const StopIdParams('x'));
  });

  late _MockGet get;
  late _MockDiscard discard;
  late int resumeRefreshes;

  setUp(() {
    get = _MockGet();
    discard = _MockDiscard();
    resumeRefreshes = 0;
    when(() => get(any())).thenAnswer((_) async => const Success(_one));
  });

  PendingVisitSyncCubit build({
    Future<bool> Function()? syncNow,
    Stream<bool>? running,
  }) =>
      PendingVisitSyncCubit(
        getPendingVisitSync: get,
        discardPendingVisitStop: discard,
        syncRunning: running,
        syncNow: syncNow,
        onStopDiscarded: () => resumeRefreshes++,
      );

  group('discard', () {
    test(
        'success: says so, lets the resume card re-read, and reloads the '
        'list', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      when(() => get(any()))
          .thenAnswer((_) async => const Success(PendingVisitSync()));
      when(() => discard(const StopIdParams('s-1'))).thenAnswer((_) async =>
          const Success(VisitStopDiscard(
              stopId: 's-1',
              discardedRecords: 3,
              reset: VisitStopReset.notVisited)));

      final states = <PendingVisitSyncState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.discard('s-1');
      await sub.cancel();

      expect(states.first.discarding, {'s-1'},
          reason: 'actions disabled while it runs');
      expect(states.map((s) => s.messageKey),
          contains('sync_center.visit.discarded'));
      expect(cubit.state.discarding, isEmpty);
      expect(cubit.state.pending.isEmpty, isTrue);
      expect(resumeRefreshes, 1);
    });

    test('failure: a translated message, the list kept, no resume refresh',
        () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      when(() => discard(any())).thenAnswer(
          (_) async => const Failed(CacheFailure(message: 'raw db text')));

      final states = <PendingVisitSyncState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.discard('s-1');
      await sub.cancel();

      expect(states.map((s) => s.messageKey),
          contains('sync_center.visit.discard_failed'));
      expect(states.map((s) => s.messageKey), isNot(contains('raw db text')));
      expect(cubit.state.pending, _one);
      expect(resumeRefreshes, 0);
    });

    test('a second tap while one runs is ignored', () async {
      final gate = Completer<Result<VisitStopDiscard>>();
      when(() => discard(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      addTearDown(cubit.close);

      final first = cubit.discard('s-1');
      await cubit.discard('s-1');
      gate.complete(const Success(VisitStopDiscard(
          stopId: 's-1',
          discardedRecords: 1,
          reset: VisitStopReset.unchanged)));
      await first;

      verify(() => discard(any())).called(1);
    });
  });

  group('syncNow', () {
    test('shows progress while the drain runs, then reloads', () async {
      final gate = Completer<bool>();
      final cubit = build(syncNow: () => gate.future);
      addTearDown(cubit.close);

      final run = cubit.syncNow();
      expect(cubit.state.syncing, isTrue);
      gate.complete(true);
      await run;

      expect(cubit.state.syncing, isFalse);
      expect(cubit.state.messageKey, isNull);
      verify(() => get(any())).called(1);
    });

    test('offline: says the visits are saved and will send later', () async {
      final cubit = build(syncNow: () async => false);
      addTearDown(cubit.close);

      final states = <PendingVisitSyncState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.syncNow();
      await sub.cancel();

      expect(states.map((s) => s.messageKey),
          contains('sync_center.visit.sync_offline'));
      expect(cubit.state.syncing, isFalse);
    });

    test('an automatic drain shows as syncing and reloads when it ends',
        () async {
      final running = StreamController<bool>.broadcast();
      final cubit = build(running: running.stream);
      addTearDown(cubit.close);
      addTearDown(running.close);

      running.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.syncing, isTrue);

      running.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.syncing, isFalse);
      verify(() => get(any())).called(1);
    });

    test('without a sync path the cubit offers no Sync', () {
      final cubit = build();
      addTearDown(cubit.close);
      expect(cubit.canSync, isFalse);
      expect(cubit.canDiscard, isTrue);
    });
  });
}
