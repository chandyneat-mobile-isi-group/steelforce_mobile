import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// `developer.log` reaches the VM service — DevTools and the IDE — but **not**
/// the `flutter run` terminal, which only shows stdout. The logger emitted
/// exclusively through `developer.log`, so a developer watching the terminal
/// during `flutter run` saw nothing at all and reasonably concluded the
/// logging was not working.
void main() {
  late List<String> printed;
  late DebugPrintCallback original;

  setUp(() {
    printed = [];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() => debugPrint = original);

  test('records reach the terminal, tagged by level', () {
    const logger = ConsoleAppLogger();

    logger.info('auth.login.start', fields: {'identifierKind': 'employeeId'});

    expect(printed, hasLength(1));
    expect(printed.single, contains('[isi.info]'));
    expect(printed.single, contains('auth.login.start'));
    expect(printed.single, contains('identifierKind=employeeId'));
  });

  test('every level shows while verbose', () {
    const logger = ConsoleAppLogger();

    logger
      ..debug('api.request')
      ..info('api.response')
      ..warning('api.slow')
      ..error('api.error');

    expect(printed.map((l) => l.split(']').first), [
      '[isi.debug',
      '[isi.info',
      '[isi.warning',
      '[isi.error',
    ]);
  });

  test('the terminal copy is redacted like the structured one', () {
    // The terminal must never be the weaker channel — it is the one most
    // likely to be screenshotted into a ticket.
    const logger = ConsoleAppLogger();

    logger.info('auth.login', fields: {
      'password': 'Test-Sales-Pass-1!',
      'employeeId': 'EMP000202',
    });

    expect(printed.single, isNot(contains('Test-Sales-Pass-1!')));
    expect(printed.single, isNot(contains('EMP000202')));
    expect(printed.single, contains(LogRedactor.placeholder));
  });

  test('release builds print nothing to the console channel', () {
    // The terminal mirror is a development aid and is switched off wholesale
    // in release — including for warnings and errors, which `developer.log`
    // still carries per SECURITY.md §11.
    //
    // The asymmetry is deliberate. There is no terminal attached to a shipped
    // build, and on Android `debugPrint` lands in logcat, which any app
    // holding READ_LOGS can read. Keeping this channel development-only means
    // the extra copy cannot widen the exposure §10 is written to prevent,
    // while the structured records stay available for diagnosis.
    const logger = ConsoleAppLogger(verbose: false);

    logger
      ..debug('api.request')
      ..info('api.response')
      ..warning('api.slow')
      ..error('api.error');

    expect(printed, isEmpty);
  });

  test('a stack trace is printed for errors only', () {
    const logger = ConsoleAppLogger();
    final trace = StackTrace.current;

    logger.warning('api.slow', fields: {'ms': 9000});
    expect(printed, hasLength(1), reason: 'warnings carry no trace');

    printed.clear();
    logger.error('api.error', error: 'boom', stackTrace: trace);
    expect(printed, hasLength(2), reason: 'the message, then the trace');
    expect(printed.first, contains('error=boom'));
  });
}
