import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/sync/background/background_sync_runner.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogger extends Mock implements AppLogger {}

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity(this.probeAnswer);

  ConnectivityStatus probeAnswer;
  int probes = 0;

  @override
  Future<ConnectivityStatus> refresh() async {
    probes++;
    return probeAnswer;
  }

  @override
  ConnectivityStatus get status => ConnectivityStatus.offline;
  @override
  bool get isOnline => false;
  @override
  Stream<ConnectivityStatus> get changes => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeSource implements UnsentWorkSource {
  _FakeSource(this.unsent);

  int unsent;
  int sends = 0;
  Duration sendTakes = Duration.zero;

  @override
  String get debugName => 'fake';

  @override
  Future<int> countUnsent() async => unsent;

  @override
  Future<int> countSendable() async => unsent;

  @override
  Future<void> sendNow() async {
    sends++;
    await Future<void>.delayed(sendTakes);
    unsent = 0;
  }
}

void main() {
  late _MockLogger logger;
  late _FakeConnectivity connectivity;
  late _FakeSource source;
  late bool signedIn;

  BackgroundSyncRunner build() => BackgroundSyncRunner(
        unsentWork: UnsentWorkService([source], logger),
        connectivity: connectivity,
        restoreSession: () async => signedIn,
        logger: logger,
      );

  setUp(() {
    logger = _MockLogger();
    connectivity = _FakeConnectivity(ConnectivityStatus.online);
    source = _FakeSource(2);
    signedIn = true;
  });

  const budget = Duration(seconds: 5);

  test('sends queued work when signed in and online', () async {
    final outcome = await build().run(budget: budget);

    expect(outcome, BackgroundSyncOutcome.sent);
    expect(source.sends, 1);
    expect(source.unsent, 0);
  });

  test('a guest sends nothing and spends no network', () async {
    signedIn = false;

    final outcome = await build().run(budget: budget);

    expect(outcome, BackgroundSyncOutcome.noSession);
    expect(connectivity.probes, 0);
    expect(source.sends, 0);
  });

  test('an empty outbox ends before any network', () async {
    source.unsent = 0;

    final outcome = await build().run(budget: budget);

    expect(outcome, BackgroundSyncOutcome.nothingQueued);
    expect(connectivity.probes, 0);
  });

  test('unreachable: nothing is sent and the work stays queued', () async {
    connectivity.probeAnswer = ConnectivityStatus.offline;

    final outcome = await build().run(budget: budget);

    expect(outcome, BackgroundSyncOutcome.offline);
    expect(source.sends, 0);
    expect(source.unsent, 2);
  });

  test('stops at the OS budget instead of being killed mid-run', () async {
    source.sendTakes = const Duration(milliseconds: 300);

    final outcome = await build().run(budget: const Duration(milliseconds: 50));

    expect(outcome, BackgroundSyncOutcome.outOfTime);
  });

  test('a failing session restore is reported, never thrown', () async {
    final runner = BackgroundSyncRunner(
      unsentWork: UnsentWorkService([source], logger),
      connectivity: connectivity,
      restoreSession: () async => throw StateError('keystore locked'),
      logger: logger,
    );

    final outcome = await runner.run(budget: budget);

    expect(outcome, BackgroundSyncOutcome.failed);
    expect(source.sends, 0);
  });
}
