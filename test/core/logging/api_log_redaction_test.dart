import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// `docs/skills/security.md` §10 is a hard constraint: passwords, tokens, e-mail
/// addresses, phone numbers, depot data and money must never reach a log
/// sink. Logs outlive the session that produced them — they end up in bug
/// reports, and on Android any app holding `READ_LOGS` can read them.
///
/// These tests pin both halves of that: the values that must never survive,
/// and the diagnostic fields that must, since a log that redacts everything is
/// as useless as one that redacts nothing.
void main() {
  const redactor = LogRedactor();

  Object? redact(String key, Object? value) => redactor.redactValue(key, value);

  group('never logged', () {
    test('the login body, field by field', () {
      // The sharp end: printing this verbatim to "debug login" writes a
      // working credential to the console.
      final safe = redactor.redact({
        'employeeId': 'ADM000001',
        'password': 'Test-Admin-Pass-1!',
        'device': {'deviceId': 'a3f1c9e0-1234-4a7f-b0d2-1f9e4c8a2b31'},
      });

      expect(safe['password'], LogRedactor.placeholder);
      expect(safe['employeeId'], LogRedactor.placeholder);
      // Nested payloads cannot smuggle anything past the key check.
      expect((safe['device']! as Map)['deviceId'], LogRedactor.placeholder);
    });

    test('a JWT, even under an innocuous key', () {
      const jwt = 'eyJhbGciOiJSUzI1NiIs.eyJzdWIiOiIxMjM0NTY.SflKxwRJSMeKKF2QT4';

      expect(redact('access_token', jwt), LogRedactor.placeholder);
      // The value-shape pass is what catches this one.
      expect(redact('v', jwt), LogRedactor.placeholder);
    });

    test('an e-mail address under any key', () {
      expect(redact('note', 'contact sonal.heng@isigroup.com.kh'),
          LogRedactor.placeholder);
    });

    test('a phone number under any key', () {
      expect(redact('v', '+85512345678'), LogRedactor.placeholder);
    });

    test('depot identity and money', () {
      final safe = redactor.redact({
        'shopName': 'Toul Kork Construction Depot',
        'creditLimit': 30000.0,
        'latitude': 11.5788,
      });

      for (final value in safe.values) {
        expect(value, LogRedactor.placeholder);
      }
    });
  });

  group('still logged, because a blind log is a useless log', () {
    test('the fields the API interceptor emits survive', () {
      // §10 explicitly allows endpoint, response code and error code. If any
      // of these start coming back redacted the interceptor stops being able
      // to answer the questions it exists for.
      final safe = redactor.redact({
        'method': 'GET',
        'path': '/api/v1/mobile/depots',
        'status': 200,
        'ms': 143,
        'errorCode': 'Depot.NotFound',
        'dioType': 'badResponse',
        'page': 1,
        'pageSize': 200,
        'records': 10,
        'hasNextPage': false,
        'isDeltaSync': true,
        'signedIn': true,
        'language': 'en-US',
        'rows': ['depots:25'],
        'queryKeys': ['pageNumber', 'pageSize', 'modifiedSince'],
      });

      expect(safe.values, isNot(contains(LogRedactor.placeholder)));
      expect(safe['status'], 200);
      expect(safe['errorCode'], 'Depot.NotFound');
      expect(safe['rows'], ['depots:25']);
      // `signedIn` rather than `authorized`: any key containing "auth" is
      // masked, which would hide whether the token was attached at all.
      expect(safe['signedIn'], isTrue);
      // `records` rather than `totalRecords`: "total" is a masked fragment.
      expect(safe['records'], 10);
    });

    test('a correlation id survives its digit run', () {
      // The single most useful value in a bug report: it is what support uses
      // to find the exact request server-side. It trips the long-digit-run
      // rule, so it is exempted by key — see LogRedactor._correlationKey.
      expect(redact('correlationId', '0HNNOE4PB87QD:00000001'),
          '0HNNOE4PB87QD:00000001');
      expect(redact('traceId', '0HNNOE4PB87QG:00000001'),
          '0HNNOE4PB87QG:00000001');
    });

    test('the correlation exemption does not become a token loophole', () {
      // The exemption skips the digit-run rule only. Something JWT- or
      // e-mail-shaped arriving under `traceId` is a bug, not an identifier.
      const jwt = 'eyJhbGciOiJSUzI1NiIs.eyJzdWIiOiIxMjM0NTY.SflKxwRJSMeKKF2QT4';

      expect(redact('traceId', jwt), LogRedactor.placeholder);
      expect(redact('correlationId', 'sonal.heng@isigroup.com.kh'),
          LogRedactor.placeholder);
    });

    test('the exemption is anchored, not a substring match', () {
      // `correlationIdToken` must not inherit the exemption.
      expect(redact('correlationIdToken', '12345678'), LogRedactor.placeholder);
    });
  });
}
