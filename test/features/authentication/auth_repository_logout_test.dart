import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _MockLocal extends Mock implements AuthLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

void main() {
  const token = AuthTokenModel(
    accessToken: 'access_1',
    refreshToken: 'refresh_1',
  );

  late _MockRemote remote;
  late _MockLocal local;
  late _MockNetwork network;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    network = _MockNetwork();
    repository = AuthRepositoryImpl(
      remote: remote,
      local: local,
      networkInfo: network,
      // Non-verbose: these tests assert behaviour, not output, and debug/info
      // records are dropped at this level.
      logger: const ConsoleAppLogger(verbose: false),
    );

    when(() => local.readToken()).thenAnswer((_) async => token);
    when(local.clear).thenAnswer((_) async {});
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => remote.logout(
        refreshToken: any(named: 'refreshToken'),
        allDevices: any(named: 'allDevices'))).thenAnswer((_) async {});
  });

  test('completes without waiting for server revocation', () async {
    // The regression this pins down. `NetworkInfo.isConnected` only reports
    // that an interface is up, so on a build with no reachable gateway the
    // revocation POST is still issued and hangs for the full connect timeout.
    // When sign-out awaited it, everything behind it stalled — including the
    // app restart that discards the authenticated screen stack, so the user
    // stayed on the screen they had just signed out of.
    final hung = Completer<void>();
    addTearDown(hung.complete);
    when(() => remote.logout(
        refreshToken: any(named: 'refreshToken'),
        allDevices: any(named: 'allDevices'))).thenAnswer((_) => hung.future);

    // Times out rather than passing if the network is ever awaited again.
    await repository.logout().timeout(const Duration(seconds: 1));

    verify(local.clear).called(1);
  });

  test('clears local state even with no connectivity', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);

    await repository.logout();

    verify(local.clear).called(1);
    verifyNever(() => remote.logout(
        refreshToken: any(named: 'refreshToken'),
        allDevices: any(named: 'allDevices')));
  });

  test('revokes with the outgoing token, read before the store is cleared',
      () async {
    await repository.logout();
    // The revocation is fire-and-forget, so let its microtasks drain.
    await Future<void>.delayed(Duration.zero);

    verifyInOrder([
      () => local.readToken(),
      local.clear,
      () => remote.logout(refreshToken: token.refreshToken, allDevices: false),
    ]);
  });

  test('a failing revocation does not fail the sign-out', () async {
    when(() => remote.logout(
            refreshToken: any(named: 'refreshToken'),
            allDevices: any(named: 'allDevices')))
        .thenThrow(Exception('gateway down'));

    await expectLater(repository.logout(), completes);
    await Future<void>.delayed(Duration.zero);

    verify(local.clear).called(1);
  });

  test('an unreadable token store still signs the user out', () async {
    when(() => local.readToken()).thenThrow(Exception('keystore locked'));

    await repository.logout();

    verify(local.clear).called(1);
    verifyNever(() => remote.logout(
        refreshToken: any(named: 'refreshToken'),
        allDevices: any(named: 'allDevices')));
  });
}
