import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogger extends Mock implements AppLogger {}

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity(this._status);

  final _changes = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _status;
  int refreshes = 0;

  void set(ConnectivityStatus status) {
    _status = status;
    _changes.add(status);
  }

  @override
  ConnectivityStatus get status => _status;
  @override
  bool get isOnline => _status == ConnectivityStatus.online;
  @override
  Stream<ConnectivityStatus> get changes => _changes.stream;
  @override
  Future<ConnectivityStatus> refresh() async {
    refreshes++;
    return _status;
  }

  @override
  Future<void> start() async {}
  @override
  Future<void> dispose() => _changes.close();
}

/// An outbox holding [unsent] items. Each send delivers [deliverPerSend] of
/// them, or throws when [throwOnSend] is set.
class _FakeSource implements UnsentWorkSource {
  _FakeSource(this.unsent);

  int unsent;

  /// Items waiting on the rep: they block sign-out but are never sent.
  int parked = 0;
  int deliverPerSend = 1 << 30;
  bool throwOnSend = false;
  int sends = 0;

  /// When set, each send waits for it — to hold a drain open.
  Completer<void>? gate;

  @override
  String get debugName => 'fake';

  @override
  Future<int> countUnsent() async => unsent + parked;

  @override
  Future<int> countSendable() async => unsent;

  @override
  Future<void> sendNow() async {
    sends++;
    await gate?.future;
    if (throwOnSend) throw StateError('boom');
    unsent = max(0, unsent - deliverPerSend);
  }
}

const _coalesce = Duration(milliseconds: 5);
const _baseRetry = Duration(milliseconds: 40);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLogger logger;
  late _FakeConnectivity connectivity;
  late _FakeSource source;
  late bool authenticated;
  late SyncEngine engine;

  SyncEngine build({Duration maxRetry = const Duration(seconds: 5)}) =>
      SyncEngine(
        unsentWork: UnsentWorkService([source], logger),
        connectivity: connectivity,
        logger: logger,
        isAuthenticated: () => authenticated,
        coalesceDelay: _coalesce,
        baseRetryDelay: _baseRetry,
        maxRetryDelay: maxRetry,
        random: Random(1),
      );

  Future<void> settle([Duration d = const Duration(milliseconds: 30)]) =>
      Future<void>.delayed(d);

  setUp(() {
    logger = _MockLogger();
    connectivity = _FakeConnectivity(ConnectivityStatus.online);
    source = _FakeSource(3);
    authenticated = true;
    engine = build();
  });

  tearDown(() => engine.stop());

  test('drains outstanding work when started online', () async {
    engine.start();
    await settle();
    expect(source.sends, 1);
    expect(source.unsent, 0);
  });

  test('does nothing for a guest', () async {
    authenticated = false;
    engine.start();
    await settle();
    expect(source.sends, 0);
  });

  test('waits while offline, then drains on reconnect', () async {
    connectivity = _FakeConnectivity(ConnectivityStatus.offline);
    engine = build();
    engine.start();
    await settle();
    expect(source.sends, 0, reason: 'nothing is sent without reachability');

    connectivity.set(ConnectivityStatus.online);
    await settle();
    expect(source.sends, 1);
    expect(source.unsent, 0);
  });

  test('skips the send entirely when nothing is queued', () async {
    source.unsent = 0;
    engine.start();
    await settle();
    expect(source.sends, 0);
  });

  test('retries while work remains and stops once it is all sent', () async {
    source.deliverPerSend = 1;
    engine.start();
    // 3 items, 1 per send: the first drain plus two retries.
    await settle(const Duration(milliseconds: 400));
    expect(source.unsent, 0);
    expect(source.sends, 3);

    await settle(const Duration(milliseconds: 200));
    expect(source.sends, 3, reason: 'no retry once the outbox is empty');
  });

  test('backs off while the server keeps refusing', () async {
    source.deliverPerSend = 0; // every row rejected, every time
    engine.start();
    // Delays: 40, 80, 160, 320 ms (+≤20% jitter). In ~450 ms a fixed-interval
    // retry would have run ~11 times; doubling allows the first drain and at
    // most three retries.
    await settle(const Duration(milliseconds: 450));
    expect(source.sends, inInclusiveRange(2, 4));
  });

  test('the backoff never exceeds the cap', () async {
    engine = build(maxRetry: const Duration(milliseconds: 50));
    source.deliverPerSend = 0;
    engine.start();
    // Capped at 50 ms (+≤20%): ~6 attempts in 400 ms, not 3–4.
    await settle(const Duration(milliseconds: 400));
    expect(source.sends, greaterThanOrEqualTo(5));
  });

  test('a throwing source does not stop later retries', () async {
    source.throwOnSend = true;
    engine.start();
    await settle(const Duration(milliseconds: 80));
    expect(source.sends, greaterThanOrEqualTo(1));

    source.throwOnSend = false;
    connectivity.set(ConnectivityStatus.online); // reconnect resets backoff
    await settle();
    expect(source.unsent, 0);
  });

  test('foreground resume re-probes reachability and drains', () async {
    source.unsent = 0;
    engine.start();
    await settle();

    source.unsent = 2;
    engine.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(connectivity.refreshes, 1);
    expect(source.unsent, 0);
  });

  test('requestSync after a local write drains', () async {
    source.unsent = 0;
    engine.start();
    await settle();

    source.unsent = 1;
    engine.requestSync();
    await settle();
    expect(source.unsent, 0);
  });

  test('a burst of triggers is coalesced into one drain', () async {
    engine.start();
    engine.requestSync();
    engine.requestSync();
    connectivity.set(ConnectivityStatus.online);
    await settle();
    expect(source.sends, 1);
  });

  test('rows parked for the rep do not keep the retry timer firing', () async {
    source.unsent = 1;
    source.parked = 3;
    engine.start();
    await settle(const Duration(milliseconds: 300));

    expect(source.unsent, 0);
    expect(source.sends, 1, reason: 'parked rows are not retried');
  });

  test('nothing is sent when only parked rows remain', () async {
    source.unsent = 0;
    source.parked = 2;
    engine.start();
    await settle();

    expect(source.sends, 0);
  });

  test('runNow during a drain waits for it, then drains again', () async {
    source.gate = Completer<void>();
    engine.start();
    await settle(); // the start-up drain is now held open

    var released = false;
    final call = engine.runNow().then((_) => released = true);
    await settle();
    expect(released, isFalse, reason: 'must not return mid-drain');

    source.unsent = 1; // saved while the first drain was running
    source.gate!.complete();
    await call;

    expect(released, isTrue);
    expect(source.unsent, 0, reason: 'the second pass picked it up');
  });

  test('stop cancels pending retries', () async {
    source.deliverPerSend = 0;
    engine.start();
    await settle();
    final sendsAtStop = source.sends;
    await engine.stop();

    await settle(const Duration(milliseconds: 200));
    expect(source.sends, sendsAtStop);
  });
}
