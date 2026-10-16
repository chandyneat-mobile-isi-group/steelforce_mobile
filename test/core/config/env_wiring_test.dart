import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/config/env.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';

/// Guards the shape of the compiled build config, not its values — the host
/// changes with every Cloudflare quick tunnel, so asserting a specific URL
/// would fail on the next restart.
///
/// The bug these exist for: `.env` used a key (`backend-api`) that matched no
/// `@EnviedField`, so `build_runner` could not run and `env.g.dart` silently
/// kept values from a long-dead host. Everything compiled, every test passed,
/// and the app simply could not reach the API.
void main() {
  test('every field is populated', () {
    // An empty value here means .env is missing a key, or codegen ran against
    // a stale file — the failure mode that cost an afternoon.
    expect(Env.apiBaseUrl, isNotEmpty, reason: 'API_BASE_URL missing');
    expect(Env.dbSalt, isNotEmpty, reason: 'DB_SALT missing');
  });

  test('the base URL is a host root, not a full API path', () {
    // ApiEndpoints.apiPrefix appends `/api/v1`. A base URL that already
    // carries it produces `/api/v1/api/v1/auth/login`, which 404s in a way
    // that reads like a routing bug on the server.
    expect(Env.apiBaseUrl, startsWith('http'));
    expect(Env.apiBaseUrl, isNot(endsWith('/')),
        reason: 'a trailing slash doubles the separator');
    expect(Env.apiBaseUrl, isNot(contains(ApiEndpoints.apiPrefix)),
        reason: 'apiPrefix is appended, so it must not be in the base URL');
  });

  test('the composed auth endpoint matches the documented contract', () {
    // The mobile app signs in at `https://<host>/api/v1/mobile/auth/login`
    // (staging OpenAPI spec, checked 2026-10-07).
    expect('${Env.apiBaseUrl}${ApiEndpoints.loginEndpoint}',
        matches(RegExp(r'^https?://[^/]+/api/v1/mobile/auth/login$')));
  });

  group('AppConfig — the values everything actually reads', () {
    test('falls through to Env when no override is given', () {
      // No --dart-define in a plain `flutter test` run.
      expect(AppConfig.hasOverride, isFalse);
      expect(AppConfig.apiBaseUrl, Env.apiBaseUrl);
    });

    test('nothing reaching the network reads Env directly', () async {
      // The override only works if every caller goes through AppConfig. One
      // client left on `Env.apiBaseUrl` would silently ignore the flag, which
      // is harder to debug than having no override at all.
      final offenders = <String>[];
      final dir = Directory('lib');

      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The wrapper and the generated/declared config are the legitimate
        // readers.
        if (entity.path.contains('core/config/')) continue;

        final source = await entity.readAsString();
        if (source.contains('Env.apiBaseUrl')) {
          offenders.add(entity.path);
        }
      }

      expect(offenders, isEmpty, reason: 'read AppConfig.apiBaseUrl instead');
    });
  });
}
