import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/bootstrap/error_boundary.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Records what reached the logger instead of printing it.
class _CapturingLogger implements AppLogger {
  final events = <String>[];
  final errors = <Object?>[];

  @override
  void debug(String event, {Map<String, Object?>? fields}) => events.add(event);

  @override
  void info(String event, {Map<String, Object?>? fields}) => events.add(event);

  @override
  void warning(String event, {Map<String, Object?>? fields}) =>
      events.add(event);

  @override
  void error(String event,
      {Object? error, StackTrace? stackTrace, Map<String, Object?>? fields}) {
    events.add(event);
    errors.add(error);
  }
}

/// Nothing was installed before this: a widget throwing during build replaced
/// the screen with Flutter's error box, an uncaught async error vanished
/// silently, and none of it reached [AppLogger] — so none of it appeared in
/// the log a bug report is built from.
void main() {
  late _CapturingLogger logger;
  late FlutterExceptionHandler? originalOnError;

  setUp(() {
    logger = _CapturingLogger();
    originalOnError = FlutterError.onError;
    ErrorBoundary.resetSeen();
  });

  tearDown(() => FlutterError.onError = originalOnError);

  testWidgets('a widget that throws during build is logged, not swallowed',
      (tester) async {
    ErrorBoundary.install(logger);

    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (_) => throw StateError('boom'))),
    );

    // The framework still records the error for the test harness; the point is
    // that our logger saw it too.
    expect(tester.takeException(), isA<StateError>());
    expect(logger.events, contains('app.flutterError'));
    expect(logger.errors.whereType<StateError>(), isNotEmpty);
  });

  testWidgets('the rest of the app keeps rendering around a failed subtree',
      (tester) async {
    ErrorBoundary.install(logger);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Text('survives'),
            Builder(builder: (_) => throw StateError('one bad row')),
          ],
        ),
      ),
    );
    tester.takeException();

    // A single broken widget must not take the screen with it.
    expect(find.text('survives'), findsOneWidget);
  });

  test('an error escaping an async callback is reported', () async {
    // These used to vanish entirely — a background sync could die and nobody
    // would learn of it.
    final done = Completer<void>();

    ErrorBoundary.runGuarded(logger, () {
      Timer.run(() {
        try {
          throw StateError('async boom');
        } finally {
          Future<void>.delayed(
            const Duration(milliseconds: 10),
            () => done.complete(),
          );
        }
      });
    });

    await done.future;
    expect(logger.events, contains('app.uncaught'));
  });

  test('the framework handler records the failing library', () {
    ErrorBoundary.install(logger);

    FlutterError.reportError(FlutterErrorDetails(
      exception: StateError('layout'),
      library: 'rendering library',
      context: ErrorDescription('while laying out MainShell'),
    ));

    expect(logger.events, contains('app.flutterError'));
  });

  test('a repeating error is counted, not repeated sixty times a second', () {
    // A render-pipeline assertion fires every frame. Logging each one in full
    // buries the first occurrence — the only one carrying useful context —
    // and makes the log useless for everything else.
    ErrorBoundary.install(logger);

    for (var i = 0; i < 200; i++) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('same every frame'),
        library: 'rendering library',
      ));
    }

    final full = logger.events.where((e) => e == 'app.flutterError').length;
    expect(full, lessThanOrEqualTo(3),
        reason: 'only the first few carry a stack trace');

    // But it is never silent — a runaway error stays visible.
    expect(logger.events, contains('app.flutterError.repeating'));
    expect(logger.events.length, lessThan(20),
        reason: '200 frames must not produce 200 log lines');
  });

  test('a different error is still reported in full', () {
    // De-duplication must not hide a *new* problem behind a noisy one.
    ErrorBoundary.install(logger);

    for (var i = 0; i < 50; i++) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('noisy'),
        library: 'rendering library',
      ));
    }
    logger.events.clear();

    FlutterError.reportError(FlutterErrorDetails(
      exception: StateError('brand new'),
      library: 'widgets library',
    ));

    expect(logger.events, contains('app.flutterError'));
  });

  testWidgets('the debug error widget is left alone', (tester) async {
    // In development the red box carries the widget-tree excerpt that makes a
    // layout error diagnosable, so it must not be replaced.
    final before = ErrorWidget.builder;
    ErrorBoundary.install(logger);

    expect(kDebugMode, isTrue, reason: 'tests run in debug');
    expect(ErrorWidget.builder, same(before),
        reason: 'the calm placeholder is release-only');
  });
}
