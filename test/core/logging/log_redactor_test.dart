import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Verifies `docs/skills/security.md` §10: "Never log passwords, JWT tokens, API keys,
/// depot information, phone numbers, emails, revenue data" and "Allowed: API
/// endpoint, response code, error code."
///
/// These are security controls, so `ENGINEERING_STANDARD.md` §10 requires 100%
/// branch coverage of this path — both the "must redact" and the "must NOT
/// redact" directions are asserted, since over-redaction that swallowed error
/// codes would quietly destroy the app's only field diagnostics.
void main() {
  const redactor = LogRedactor();

  group('LogRedactor — forbidden values (SECURITY §10)', () {
    test('redacts secrets and tokens by key name', () {
      final result = redactor.redact({
        'password': 'hunter2',
        'accessToken': 'abc',
        'refresh_token': 'def',
        'apiKey': 'k-123',
        'authorization': 'Bearer xyz',
      });

      expect(
        result.values,
        everyElement(equals(LogRedactor.placeholder)),
        reason: 'no secret may reach a log sink',
      );
    });

    test('redacts depot PII by key name', () {
      final result = redactor.redact({
        'depotName': 'Sok Dara',
        'ownerName': 'Chan',
        'email': 'a@b.com',
        'phone': '012345678',
        'address': 'St 271',
        'shopName': 'ISI Hardware',
      });

      expect(result.values, everyElement(equals(LogRedactor.placeholder)));
    });

    test('redacts revenue/pricing data by key name', () {
      final result = redactor.redact({
        'revenue': 1000,
        'totalAmount': 42.5,
        'creditLimit': 900,
        'discount': 5,
      });

      expect(result.values, everyElement(equals(LogRedactor.placeholder)));
    });

    test('redacts GPS coordinates — a depot location is depot PII', () {
      final result = redactor.redact({'latitude': 11.55, 'lng': 104.91});

      expect(result.values, everyElement(equals(LogRedactor.placeholder)));
    });

    test('redacts a JWT smuggled under an innocuous key', () {
      final result = redactor.redact({
        'v': 'eyJhbGciOi.eyJzdWIiOiK.SflKxwRJSMeKK',
      });

      expect(
        result['v'],
        LogRedactor.placeholder,
        reason: 'value-shape matching must catch what key matching misses',
      );
    });

    test('redacts an email smuggled under an innocuous key', () {
      final result = redactor.redact({'note': 'ping rep@isi.com.kh today'});

      expect(result['note'], LogRedactor.placeholder);
    });

    test('redacts long digit runs (phone/account numbers)', () {
      final result = redactor.redact({'ref': '85512345678'});

      expect(result['ref'], LogRedactor.placeholder);
    });

    test('redacts nested maps and lists', () {
      final result = redactor.redact({
        'payload': {
          'depot': {'phone': '012345678'},
        },
        'items': ['plain', 'user@x.com'],
      });

      final payload = result['payload']! as Map<String, Object?>;
      expect(payload['depot'], LogRedactor.placeholder);
      expect((result['items']! as List).last, LogRedactor.placeholder);
    });
  });

  group('LogRedactor — allowed values (SECURITY §10)', () {
    test('preserves endpoint, response code and error code', () {
      final result = redactor.redact({
        'endpoint': '/api/v1/depots',
        'statusCode': 503,
        'errorCode': 'SAP_TIMEOUT',
      });

      expect(result['endpoint'], '/api/v1/depots');
      expect(result['statusCode'], 503);
      expect(result['errorCode'], 'SAP_TIMEOUT');
    });

    test('preserves small diagnostic numbers and booleans', () {
      final result = redactor.redact({
        'attempt': 3,
        'durationMs': 1250,
        'reachable': false,
      });

      expect(result['attempt'], 3);
      expect(result['durationMs'], 1250);
      expect(result['reachable'], false);
    });

    test('null fields map returns an empty map, not null', () {
      expect(redactor.redact(null), isEmpty);
    });
  });
}
