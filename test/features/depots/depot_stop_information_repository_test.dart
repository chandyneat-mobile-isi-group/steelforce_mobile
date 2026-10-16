import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/remote/depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_stop_information_repository_impl.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:mocktail/mocktail.dart';

/// How the stop-information repository reports what it could not get.
///
/// The load-bearing rule is the 404: the server answers "no such outlet" and
/// "you are not entitled to see it" **identically, on purpose** — telling them
/// apart would confirm an outlet exists to someone not allowed to know. So the
/// client must not present either as "deleted".
class _MockRemote extends Mock
    implements DepotStopInformationRemoteDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

void main() {
  late _MockRemote remote;
  late _MockNetwork network;
  late DepotStopInformationRepositoryImpl repository;

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

  setUp(() {
    remote = _MockRemote();
    network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = DepotStopInformationRepositoryImpl(
      remote: remote,
      network: network,
      logger: const ConsoleAppLogger(verbose: false),
    );
  });

  test('a good response comes back as the profile', () async {
    when(() => remote.fetch(any())).thenAnswer((_) async => info);

    final result = await repository.fetch('d1');

    expect(result.when(success: (i) => i.outlet.code, failure: (_) => null),
        '6100000123');
  });

  group('404', () {
    ApiException notFound() => ApiException(
          const ApiError(statusCode: 404, code: 'Depot.NotFound'),
        );

    test('is its own failure type, never a generic server error', () async {
      when(() => remote.fetch(any())).thenThrow(notFound());

      final failure = await repository
          .fetch('d1')
          .then((r) => r.when(success: (_) => null, failure: (f) => f));

      expect(failure, isA<DepotStopInformationUnavailableFailure>(),
          reason: 'a distinct type is what stops a screen phrasing this as '
              '"deleted" — the outlet may well exist');
      expect(failure, isNot(isA<NetworkFailure>()));
    });

    test('its message does not claim the outlet is gone', () async {
      when(() => remote.fetch(any())).thenThrow(notFound());

      final failure = await repository
          .fetch('d1')
          .then((r) => r.when(success: (_) => null, failure: (f) => f));

      final message = failure!.message.toLowerCase();
      for (final forbidden in const ['delete', 'removed', 'no longer']) {
        expect(message, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  test('a 500 is a plain server failure, and stays retryable', () async {
    when(() => remote.fetch(any())).thenThrow(
        ApiException(const ApiError(statusCode: 500, code: 'Server.Error')));

    final failure = await repository
        .fetch('d1')
        .then((r) => r.when(success: (_) => null, failure: (f) => f));

    expect(failure, isA<ServerFailure>());
    expect(failure, isNot(isA<DepotStopInformationUnavailableFailure>()));
  });

  test('offline is reported as offline, and never reaches the network',
      () async {
    // Offline is a normal state, not an error state (ADR-0002 §4).
    when(() => network.isConnected).thenAnswer((_) async => false);

    final failure = await repository
        .fetch('d1')
        .then((r) => r.when(success: (_) => null, failure: (f) => f));

    expect(failure, isA<NetworkFailure>());
    verifyNever(() => remote.fetch(any()));
  });

  test('an empty id is refused before a request is spent', () async {
    final failure = await repository
        .fetch('  ')
        .then((r) => r.when(success: (_) => null, failure: (f) => f));

    expect(failure, isA<DepotStopInformationUnavailableFailure>());
    verifyNever(() => remote.fetch(any()));
  });
}
