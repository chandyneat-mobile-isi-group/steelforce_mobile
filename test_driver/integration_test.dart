import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Host side of `flutter drive` for device tests run by the QA automation
/// framework (`automation/`).
///
/// Writes `results.json` (each test's outcome, recorded by
/// `integration_test/support/automation_harness.dart`) and every screenshot
/// into the folders the framework passes in. Run by hand, they default to
/// `build/integration_test/`.
Future<void> main() {
  final env = Platform.environment;
  final evidence =
      Directory(env['AUTOMATION_DEVICE_EVIDENCE'] ?? 'build/integration_test');
  final screenshots = Directory(
      env['AUTOMATION_SCREENSHOT_DIR'] ?? '${evidence.path}/screenshots');
  final saved = <String>[];

  return integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('${screenshots.path}/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      if (!saved.contains(file.path)) saved.add(file.path);
      return true;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final outcomes =
          data?['automation_outcomes'] ?? const <String, dynamic>{};
      evidence.createSync(recursive: true);
      File('${evidence.path}/results.json').writeAsStringSync(
        jsonEncode({'tests': outcomes, 'screenshots': saved}),
      );
    },
  );
}
