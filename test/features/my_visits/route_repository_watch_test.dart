import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocal extends Mock implements RouteLocalDataSource {}

RoutePlanModel _route(String id) => RoutePlanModel(
      id: id,
      name: 'Route $id',
      repId: 'E1',
      repName: 'Rep',
      territory: 'PP',
      visitDate: DateTime.utc(2026, 7, 20),
      plannedStart: DateTime.utc(2026, 7, 20, 8),
      plannedEnd: DateTime.utc(2026, 7, 20, 17),
      status: RouteStatus.planned,
      stops: const [],
    );

/// Stubs the mutation used to trigger a broadcast. Without this the mock
/// returns `null` where a `Future<void>` is expected.
void _stubMutation(_MockLocal local) {
  when(() => local.updateRouteStatus(any(), any())).thenAnswer((_) async {});
}

void main() {
  setUpAll(() => registerFallbackValue(RouteStatus.planned));

  group('watchAllRoutes', () {
    test('emits the initial local snapshot', () async {
      final local = _MockLocal();
      when(local.fetchAllRoutes).thenAnswer((_) async => [_route('A')]);

      _stubMutation(local);
      final repo = RouteRepositoryImpl(local);
      final first = await repo.watchAllRoutes().first;

      expect(first.single.id, 'A');
    });

    test(
        'a mutation landing while the initial read is still in flight is not '
        'dropped', () async {
      final local = _MockLocal();

      // Hold the initial read open so a mutation can land inside the window
      // that the old `async*` implementation left unsubscribed.
      final gate = Completer<List<RoutePlanModel>>();
      var call = 0;
      when(local.fetchAllRoutes).thenAnswer((_) {
        call++;
        // First call is the initial snapshot (held open); later calls are the
        // broadcast re-reads triggered by a mutation.
        return call == 1 ? gate.future : Future.value([_route('FRESH')]);
      });

      _stubMutation(local);
      final repo = RouteRepositoryImpl(local);
      final seen = <String>[];
      final sub =
          repo.watchAllRoutes().listen((routes) => seen.add(routes.single.id));

      // Let onListen run and the upstream subscription attach.
      await Future<void>.delayed(Duration.zero);

      // A mutation completes *before* the initial read resolves. Under the old
      // implementation the generator had not yet reached `yield*`, so the
      // controller had no listener and the `hasListener` guard discarded this.
      await repo.updateRouteStatus('A', RouteStatus.inProgress);
      await Future<void>.delayed(Duration.zero);

      // Now let the slow initial read finish with stale data.
      gate.complete([_route('STALE')]);
      await Future<void>.delayed(Duration.zero);

      expect(seen, contains('FRESH'),
          reason: 'the mid-read mutation must reach the listener');
      expect(seen, isNot(contains('STALE')),
          reason: 'a slow initial read must not overwrite newer live data');

      await sub.cancel();
    });

    test('cancelling the returned stream detaches from the broadcast hub',
        () async {
      final local = _MockLocal();
      when(local.fetchAllRoutes).thenAnswer((_) async => [_route('A')]);

      _stubMutation(local);
      final repo = RouteRepositoryImpl(local);
      final sub = repo.watchAllRoutes().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // Drop the initial read from the call log, then assert a mutation
      // triggers no further reads — i.e. onCancel really detached from the
      // broadcast hub and left no leaked subscription behind.
      clearInteractions(local);
      await repo.updateRouteStatus('A', RouteStatus.completed);
      await Future<void>.delayed(Duration.zero);

      verifyNever(local.fetchAllRoutes);
    });
  });
}
