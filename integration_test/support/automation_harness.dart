import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Device-test harness for the QA automation framework (`automation/`).
///
/// Use [automationTest] instead of `testWidgets` in `integration_test/`. It
/// records every test's outcome in the binding's report data — the stock
/// response lists only failures — and takes a screenshot the moment a test
/// fails, so `test_driver/integration_test.dart` can save both as evidence.

const _outcomesKey = 'automation_outcomes';

IntegrationTestWidgetsFlutterBinding ensureAutomationBinding() =>
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

bool _surfaceConverted = false;

Map<String, dynamic> _outcomes() {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final data = binding.reportData ??= <String, dynamic>{};
  return data.putIfAbsent(_outcomesKey, () => <String, dynamic>{})
      as Map<String, dynamic>;
}

String _slug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

void automationTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Timeout? timeout,
}) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
      // A framework error (overflow, build exception) is reported after the
      // body returns; surface it here so it is recorded and screenshotted.
      final pending = tester.takeException();
      if (pending != null) throw pending as Object;
      _outcomes()[description] = {'result': 'success'};
    } catch (error) {
      _outcomes()[description] = {
        'result': 'failure',
        'details': error.toString(),
      };
      await captureScreen(tester, '${_slug(description)}-failure');
      rethrow;
    }
  }, timeout: timeout);
}

/// Saves a screenshot as evidence. Never fails the test: missing evidence is
/// reported by the host, not turned into a product failure.
Future<void> captureScreen(WidgetTester tester, String name) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  try {
    if (!kIsWeb && Platform.isAndroid && !_surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      _surfaceConverted = true;
    }
    await tester.pump();
    await binding.takeScreenshot(_slug(name));
  } catch (error) {
    debugPrint('automation: screenshot "$name" not taken: $error');
  }
}

/// Pumps real frames until [condition] holds, or fails after [timeout].
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out after ${timeout.inSeconds}s waiting for '
          '${reason ?? 'the expected state'}.');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Records that a response was made up by the test, not sent by the backend.
/// The automation framework reads these lines so that a failure is never
/// pinned on the backend for a response it never sent.
void noteInjectedResponse(String method, String path, int status) =>
    debugPrint('[automation] injected response: $method $path $status');
