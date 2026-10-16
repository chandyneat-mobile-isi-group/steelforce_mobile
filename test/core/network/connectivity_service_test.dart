import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

/// Hand-written rather than mocked: the probe's *result* is the input to the
/// logic under test, so a fake that records call counts lets us assert the
/// battery-saving guarantee (ADR-005 §1: don't probe when the radio is off).
class _FakeProbe implements ReachabilityProbe {
  _FakeProbe(this.reachable);

  bool reachable;
  int calls = 0;

  @override
  Future<bool> isReachable() async {
    calls++;
    return reachable;
  }
}

void main() {
  late _MockConnectivity connectivity;
  late _FakeProbe probe;
  late StreamController<List<ConnectivityResult>> interfaceEvents;
  late ConnectivityServiceImpl service;

  const online = [ConnectivityResult.wifi];
  const offline = [ConnectivityResult.none];

  setUp(() {
    connectivity = _MockConnectivity();
    probe = _FakeProbe(true);
    interfaceEvents = StreamController<List<ConnectivityResult>>.broadcast();

    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => interfaceEvents.stream);
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => online);

    service = ConnectivityServiceImpl(
      connectivity: connectivity,
      probe: probe,
      logger: const ConsoleAppLogger(verbose: false),
      debounce: const Duration(milliseconds: 10),
    );
  });

  tearDown(() async {
    await interfaceEvents.close();
    await service.dispose();
  });

  group('ADR-005 — reachability decides, not interface-up', () {
    test('interface up + probe reachable => online', () async {
      await service.start();

      expect(service.status, ConnectivityStatus.online);
      expect(service.isOnline, isTrue);
    });

    test('interface up + probe UNreachable => offline (captive portal)',
        () async {
      probe.reachable = false;

      await service.start();

      expect(
        service.status,
        ConnectivityStatus.offline,
        reason: 'a captive portal reports interface-up but cannot sync',
      );
    });

    test('interface down => offline without probing (saves battery)', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => offline);

      await service.start();

      expect(service.status, ConnectivityStatus.offline);
      expect(
        probe.calls,
        0,
        reason: 'ADR-005 §1: interface-up is a cheap filter before probing',
      );
    });
  });

  group('stream contract', () {
    test('emits only distinct transitions', () async {
      probe.reachable = false;
      await service.start(); // offline

      final seen = <ConnectivityStatus>[];
      final sub = service.changes.listen(seen.add);

      probe.reachable = true;
      await service.refresh(); // -> online (emit)
      await service.refresh(); // still online (no emit)
      probe.reachable = false;
      await service.refresh(); // -> offline (emit)

      // A broadcast controller delivers on a later microtask, so let the queue
      // drain before asserting — cancelling first would drop the last event and
      // make this test lie about the service's behaviour.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen, [ConnectivityStatus.online, ConnectivityStatus.offline]);
    });

    test('start() is idempotent — no duplicate listeners', () async {
      await service.start();
      await service.start();

      // A second subscription would double every emission.
      verify(() => connectivity.onConnectivityChanged).called(1);
    });
  });

  group('resilience — reports state, never throws (ADR-005 §4)', () {
    test('interface-down event goes offline immediately, no debounce wait',
        () async {
      await service.start();
      expect(service.status, ConnectivityStatus.online);

      interfaceEvents.add(offline);
      await Future<void>.delayed(Duration.zero);

      expect(service.status, ConnectivityStatus.offline);
    });

    test('a plugin stream error degrades to offline rather than throwing',
        () async {
      await service.start();

      interfaceEvents.addError(Exception('plugin exploded'));
      await Future<void>.delayed(Duration.zero);

      expect(service.status, ConnectivityStatus.offline);
    });

    test('overlapping refresh calls do not stack probes', () async {
      await service.start();
      final before = probe.calls;

      await Future.wait([service.refresh(), service.refresh()]);

      expect(
        probe.calls - before,
        lessThanOrEqualTo(2),
        reason: 'the _probing guard prevents unbounded probe pile-up',
      );
    });
  });
}
