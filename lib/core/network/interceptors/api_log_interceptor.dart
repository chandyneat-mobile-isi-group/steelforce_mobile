import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';

/// Logs every API call — method, path, status, duration and error code — so an
/// integration problem is visible in the console without a proxy or a debugger.
///
/// Records surface via `dart:developer`, so they appear in the `flutter run`
/// console and in the DevTools log view, tagged `isi.debug` / `isi.error`.
///
/// ## What is deliberately *not* logged
///
/// `docs/skills/security.md` §10 is a hard constraint, not a preference: passwords,
/// tokens, e-mail addresses, phone numbers, depot names and money never go
/// to a log sink. Logs outlive the session that produced them — they are read
/// by other people, pulled into bug reports, and on Android any app holding
/// `READ_LOGS` can read them.
///
/// The login request is the sharp end of this. Its body is
/// `{employeeId, password, device}`; printing it verbatim, which is the
/// obvious way to "debug login", writes a working credential to the console.
/// Every field logged here goes through [LogRedactor] instead, which redacts
/// by key name *and* by value shape, so a JWT or an address that arrives under
/// an innocuous key is still caught.
///
/// ## When you need the actual payload
///
/// Sometimes you genuinely need to see what the server sent. That is off by
/// default and opt-in per run:
///
/// ```
/// flutter run --dart-define=API_LOG_BODIES=true
/// ```
///
/// Bodies are still redacted before printing, and the flag is ignored entirely
/// in release builds. Keep it to your own machine — it is a debugging aid, not
/// something to leave on in a shared build.
class ApiLogInterceptor extends Interceptor {
  const ApiLogInterceptor(this._logger);

  final AppLogger _logger;

  /// Opt-in payload logging. Redacted even when enabled, and forced off in
  /// release builds regardless of what was passed at build time.
  static const bool logBodies =
      bool.fromEnvironment('API_LOG_BODIES', defaultValue: false) &&
          !kReleaseMode;

  static const _startedAtKey = '__api_log_started_at__';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();

    _logger.debug('api.request', fields: {
      'method': options.method,
      'path': options.path,
      // Keys only. Values can carry a `search` term (a depot name) or a
      // `modifiedSince` watermark; the keys alone answer "was the filter
      // actually sent?", which is the usual question.
      'queryKeys': options.queryParameters.keys.toList(),
      'correlationId': options.headers['X-Correlation-Id'],
      'language': options.headers['Accept-Language'],
      // No `signedIn` here on purpose. This interceptor is registered *ahead*
      // of [AuthInterceptor] so a 401 is logged before refresh-and-replay
      // swallows it — which means the bearer token has not been attached yet
      // when this runs. Reporting it here printed `signedIn=false` on every
      // request including ones that then returned 200, which is worse than
      // not reporting it: it sent two people hunting a missing token that was
      // in fact present. It is logged on the response instead, where the
      // header is on the same (mutated) RequestOptions.
      if (logBodies) 'body': options.data,
    });

    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    _logger.debug('api.response', fields: {
      'method': response.requestOptions.method,
      'path': response.requestOptions.path,
      'status': response.statusCode,
      'ms': _elapsedMs(response.requestOptions),
      'signedIn': _wasSignedIn(response.requestOptions),
      // The single most useful line when a list comes back empty: it separates
      // "the server sent nothing" from "the client dropped it on the floor".
      ..._payloadShape(response.data),
      if (logBodies) 'body': response.data,
    });

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = ApiError.fromDio(err);

    _logger.error('api.error', fields: {
      'method': err.requestOptions.method,
      'path': err.requestOptions.path,
      // The host the request actually went to, not the one in `.env`.
      //
      // Envied compiles `.env` into `env.g.dart` at build time, so editing the
      // file changes nothing until `build_runner` runs again. That gap made a
      // dead-host failure indistinguishable from a live one: the log said
      // `connectionError`, the developer checked `.env`, saw a working URL,
      // and reasonably concluded the network was broken. Printing the host
      // here makes the mismatch obvious in the failure itself.
      'host': err.requestOptions.uri.host,
      'status': err.response?.statusCode,
      'ms': _elapsedMs(err.requestOptions),
      // Accurate by now: [AuthInterceptor] mutates this same options object,
      // so a token attached downstream is visible here.
      'signedIn': _wasSignedIn(err.requestOptions),
      // The stable platform code — the thing to branch on and to quote in a
      // bug report, and explicitly allowed by §10.
      'errorCode': error.code,
      'correlationId': error.correlationId,
      'dioType': err.type.name,
      if (error.fieldErrors.isNotEmpty)
        'invalidFields': error.fieldErrors.keys.toList(),
      if (logBodies) 'body': err.response?.data,
    });

    handler.next(err);
  }

  /// Whether a bearer token went out with the request.
  ///
  /// Named `signedIn` rather than `authorized` because [LogRedactor] masks any
  /// key containing "auth" — the obvious name prints ***REDACTED*** and hides
  /// the one thing the field exists to answer.
  bool _wasSignedIn(RequestOptions options) =>
      options.headers.containsKey('Authorization');

  int? _elapsedMs(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is! DateTime) return null;
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  /// Describes the payload without printing it: how many rows came back and
  /// what the envelope's paging said. Enough to debug a sync without emitting
  /// a single depot record.
  Map<String, Object?> _payloadShape(Object? data) {
    if (data is! Map) return const {};

    final payload = data['data'];
    final metadata = data['metadata'];

    return {
      // Counts are collapsed into one `rows` list of `"name:count"` strings
      // rather than a field per collection. A key like `depotsCount` would
      // be masked outright — [LogRedactor] matches "depot" anywhere in a key
      // name — whereas `rows` is neutral and its string values pass the
      // value-shape checks untouched.
      if (payload is Map)
        'rows': [
          for (final entry in payload.entries)
            if (entry.value is List)
              '${entry.key}:${(entry.value as List).length}',
        ],
      if (payload is List) 'rows': ['data:${payload.length}'],
      if (metadata is Map) ...{
        'page': metadata['page'],
        // Read back rather than assumed: the server clamps rather than
        // rejecting, so this is where a silently reduced page size shows up.
        'pageSize': metadata['pageSize'],
        // `records`, not `totalRecords` — "total" is a masked key fragment.
        'records': metadata['totalRecords'],
        'hasNextPage': metadata['hasNextPage'],
        'isDeltaSync': metadata['isDeltaSync'],
        'syncTimestamp': metadata['syncTimestamp'],
      },
    };
  }
}
