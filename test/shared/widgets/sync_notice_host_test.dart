import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';
import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/core/sync/sync_engine.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/shared/widgets/sync_notice_host.dart';

class _Connectivity implements ConnectivityService {
  _Connectivity(this._status);
  final _changes = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _status;

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
  Future<ConnectivityStatus> refresh() async => _status;
  @override
  Future<void> start() async {}
  @override
  Future<void> dispose() => _changes.close();
}

/// [unsent] items; each send delivers [deliver] of them.
class _Outbox implements UnsentWorkSource {
  _Outbox(this.unsent);
  int unsent;
  int deliver = 1 << 30;

  @override
  String get debugName => 'outbox';
  @override
  Future<int> countUnsent() async => unsent;
  @override
  Future<int> countSendable() async => unsent;
  @override
  Future<void> sendNow() async => unsent = max(0, unsent - deliver);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => LocalizationService.instance.load('en'));

  late _Connectivity connectivity;
  late _Outbox outbox;
  late SyncEngine engine;
  late GlobalKey<ScaffoldMessengerState> messengerKey;

  setUp(() {
    connectivity = _Connectivity(ConnectivityStatus.online);
    outbox = _Outbox(0);
    engine = SyncEngine(
      unsentWork:
          UnsentWorkService([outbox], const ConsoleAppLogger(verbose: false)),
      connectivity: connectivity,
      logger: const ConsoleAppLogger(verbose: false),
      isAuthenticated: () => true,
      coalesceDelay: const Duration(milliseconds: 5),
      baseRetryDelay: const Duration(seconds: 30),
    );
    messengerKey = GlobalKey<ScaffoldMessengerState>();
  });

  Future<void> pumpHost(WidgetTester tester, {Key? appKey}) =>
      tester.pumpWidget(MaterialApp(
        key: appKey,
        theme: AppTheme.light(AppTypography.latinFontFamily),
        scaffoldMessengerKey: messengerKey,
        builder: (context, child) => SyncNoticeHost(
          messengerKey: messengerKey,
          engine: engine,
          connectivity: connectivity,
          child: child!,
        ),
        home: const Scaffold(body: Text('home')),
      ));

  /// Lets the engine's coalesce timer and async counts run.
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('going offline: the rep is told their work is safe',
      (tester) async {
    await pumpHost(tester);
    engine.start();
    addTearDown(engine.stop);

    connectivity.set(ConnectivityStatus.offline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets('back online: offline work is sent and the rep told so',
      (tester) async {
    await pumpHost(tester);
    connectivity.set(ConnectivityStatus.offline);
    engine.start();
    addTearDown(engine.stop);
    await drain(tester);

    // Three items saved while offline.
    outbox.unsent = 3;
    connectivity.set(ConnectivityStatus.online);
    await drain(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(outbox.unsent, 0, reason: 'sent without the rep doing anything');
    expect(find.text('Back online. All 3 item(s) synced.'), findsOneWidget);
  });

  testWidgets('some still waiting: says how many, and that it will retry',
      (tester) async {
    await pumpHost(tester);
    connectivity.set(ConnectivityStatus.offline);
    engine.start();
    addTearDown(engine.stop);
    await drain(tester);

    outbox
      ..unsent = 3
      ..deliver = 2;
    connectivity.set(ConnectivityStatus.online);
    await drain(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('2 item(s) synced, 1 still waiting'),
        findsOneWidget);
    // ...and it does: the engine's retry sends the last one by itself.
    outbox.deliver = 1 << 30;
    await tester.pump(const Duration(seconds: 40));
    await drain(tester);
    expect(outbox.unsent, 0);
  });

  testWidgets('back online with nothing waiting: no message', (tester) async {
    await pumpHost(tester);
    connectivity.set(ConnectivityStatus.offline);
    engine.start();
    addTearDown(engine.stop);
    await drain(tester);
    await tester.pump(const Duration(seconds: 6)); // offline notice expires

    connectivity.set(ConnectivityStatus.online);
    await drain(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('signed out (engine not started): nothing is shown',
      (tester) async {
    await pumpHost(tester);
    connectivity.set(ConnectivityStatus.offline);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsNothing);
  });

  // The crash in the field log: a sign-out or language change rebuilds
  // MaterialApp under a new key while a snackbar is still animating.
  testWidgets('the app restarting under a snackbar does not throw',
      (tester) async {
    await pumpHost(tester, appKey: const ValueKey('lang_en_r0'));
    messengerKey.currentState!
        .showSnackBar(const SnackBar(content: Text('Registration sent')));
    await tester.pump(const Duration(milliseconds: 100));

    await pumpHost(tester, appKey: const ValueKey('lang_en_r1'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
    // Still usable after the restart.
    messengerKey.currentState!
        .showSnackBar(const SnackBar(content: Text('After restart')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('After restart'), findsOneWidget);
  });
}
