import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/stop_information_cubit.dart';
import 'package:mocktail/mocktail.dart';

/// Loading the outlet profile behind a stop.
///
/// The behaviour that matters is what happens when it *fails*: the stop screen
/// must stay usable. The route sync has already given the rep a name, a pin and
/// a geofence, and those are what someone standing outside a shop actually
/// needs — a missing credit limit must not take the screen with it.
class _MockRepository extends Mock implements DepotStopInformationRepository {}

void main() {
  late _MockRepository repository;

  const info = DepotStopInformation(
    outlet: DepotOutletProfile(
      id: 'd1',
      code: '6100000123',
      name: 'Sok Heng Hardware',
      phone: '012345678',
      address: 'Street 271',
      outletType: 'Wholesaler',
    ),
    credit: DepotCreditProfile(
      creditLimit: Money(50000, 'USD'),
      creditBalance: Money(12500, 'USD'),
      availableCredit: Money(37500, 'USD'),
      currency: 'USD',
    ),
  );

  setUp(() => repository = _MockRepository());

  blocTest<StopInformationCubit, StopInformationState>(
    'a loaded profile reaches the screen',
    build: () {
      when(() => repository.fetch(any()))
          .thenAnswer((_) async => const Success(info));
      return StopInformationCubit(repository);
    },
    act: (cubit) => cubit.load('d1'),
    expect: () => const [
      StopInformationLoading(),
      StopInformationReady(info),
    ],
  );

  blocTest<StopInformationCubit, StopInformationState>(
    'it asks for the depot id the route sync put on the stop',
    build: () {
      when(() => repository.fetch(any()))
          .thenAnswer((_) async => const Success(info));
      return StopInformationCubit(repository);
    },
    act: (cubit) => cubit.load('01a03189-0000-0000-0000-000000000001'),
    verify: (_) =>
        verify(() => repository.fetch('01a03189-0000-0000-0000-000000000001'))
            .called(1),
  );

  blocTest<StopInformationCubit, StopInformationState>(
    'a 404 is unavailable, and is not flagged as offline',
    build: () {
      when(() => repository.fetch(any())).thenAnswer(
          (_) async => const Failed(DepotStopInformationUnavailableFailure()));
      return StopInformationCubit(repository);
    },
    act: (cubit) => cubit.load('d1'),
    verify: (cubit) {
      final state = cubit.state as StopInformationUnavailable;
      // "Not available to you" is not "you have no signal" — telling a rep to
      // check their connection would send them chasing the wrong thing.
      expect(state.isOffline, isFalse);
      expect(state.message.toLowerCase(), isNot(contains('delete')));
    },
  );

  blocTest<StopInformationCubit, StopInformationState>(
    'offline is reported as offline, not as an error',
    build: () {
      when(() => repository.fetch(any()))
          .thenAnswer((_) async => const Failed(NetworkFailure()));
      return StopInformationCubit(repository);
    },
    act: (cubit) => cubit.load('d1'),
    verify: (cubit) {
      // Offline is a normal state, not an error state (ADR-0002 §4).
      expect((cubit.state as StopInformationUnavailable).isOffline, isTrue);
    },
  );

  blocTest<StopInformationCubit, StopInformationState>(
    'an unreachable gateway also counts as offline for the rep',
    build: () {
      when(() => repository.fetch(any()))
          .thenAnswer((_) async => const Failed(ServerUnreachableFailure()));
      return StopInformationCubit(repository);
    },
    act: (cubit) => cubit.load('d1'),
    verify: (cubit) =>
        expect((cubit.state as StopInformationUnavailable).isOffline, isTrue),
  );

  blocTest<StopInformationCubit, StopInformationState>(
    'a server error is surfaced, but not as offline',
    build: () {
      when(() => repository.fetch(any())).thenAnswer((_) async =>
          const Failed(ServerFailure(message: 'Boom', statusCode: 500)));
      return StopInformationCubit(repository);
    },
    act: (cubit) => cubit.load('d1'),
    verify: (cubit) {
      final state = cubit.state as StopInformationUnavailable;
      expect(state.isOffline, isFalse);
      expect(state.message, 'Boom');
    },
  );

  test('it does not emit after being closed', () async {
    // The rep can leave a stop while the fetch is still in flight; emitting
    // into a closed cubit throws and takes the route with it.
    when(() => repository.fetch(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const Success(info);
    });

    final cubit = StopInformationCubit(repository);
    final pending = cubit.load('d1');
    await cubit.close();

    await expectLater(pending, completes);
  });
}
