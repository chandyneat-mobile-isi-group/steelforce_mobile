import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity of a log record. Ordered: [debug] is the most verbose.
enum LogLevel { debug, info, warning, error }

/// Structured, PII-free application logger.
///
/// Implements `docs/skills/security.md` §10 (MASVS-PRIVACY / MASVS-CODE), which is a
/// **hard constraint on every logging call in the codebase**, not a guideline:
///
/// - **Never logged**: passwords, JWT/tokens, API keys, depot information,
///   phone numbers, emails, revenue data.
/// - **Allowed**: API endpoint, response code, error code, and — in development
///   builds only — exception stack traces (stripped from release per §11).
///
/// Callers pass an [event] name plus structured [fields] rather than an
/// interpolated sentence, so records stay greppable and machine-readable and so
/// every value can be run through [LogRedactor] before it is emitted. Defence in
/// depth: a caller that passes PII by mistake gets it redacted rather than
/// leaked, but callers are still expected not to pass it (§10).
///
/// This is deliberately the only logging surface in `core/` — see
/// `docs/skills/engineering-standard.md` §7: a `catch` block either rethrows a typed
/// `Failure` or logs through this logger. Silent `catch (_) {}` is not
/// acceptable in reviewed code.
abstract interface class AppLogger {
  /// Verbose diagnostics. Suppressed in release builds (`SECURITY.md` §11).
  void debug(String event, {Map<String, Object?>? fields});

  /// Notable lifecycle events (bootstrap steps, connectivity transitions).
  /// Suppressed in release builds (`SECURITY.md` §11).
  void info(String event, {Map<String, Object?>? fields});

  /// Recoverable problems worth surfacing. Retained in release builds.
  void warning(String event, {Map<String, Object?>? fields});

  /// Failures. Retained in release builds; [stackTrace] is emitted only in
  /// development builds (`SECURITY.md` §10, §11).
  void error(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  });
}

/// Default [AppLogger]: emits via `dart:developer` so records surface in the
/// IDE/DevTools without adding a third-party logging dependency (a new package
/// would need the maintenance/trust check in `docs/skills/security.md` §14).
///
/// Release behaviour per `SECURITY.md` §11 ("verbose logging disabled"):
/// [debug] and [info] are dropped entirely; [warning]/[error] are kept without
/// stack traces so field failures remain diagnosable without leaking internals.
class ConsoleAppLogger implements AppLogger {
  const ConsoleAppLogger({
    LogRedactor redactor = const LogRedactor(),
    bool? verbose,
  })  : _redactor = redactor,
        _verbose = verbose ?? !kReleaseMode;

  final LogRedactor _redactor;

  /// When false, [debug]/[info] are dropped and stack traces are withheld.
  final bool _verbose;

  @override
  void debug(String event, {Map<String, Object?>? fields}) =>
      _emit(LogLevel.debug, event, fields);

  @override
  void info(String event, {Map<String, Object?>? fields}) =>
      _emit(LogLevel.info, event, fields);

  @override
  void warning(String event, {Map<String, Object?>? fields}) =>
      _emit(LogLevel.warning, event, fields);

  @override
  void error(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) =>
      _emit(
        LogLevel.error,
        event,
        fields,
        error: error,
        stackTrace: stackTrace,
      );

  void _emit(
    LogLevel level,
    String event,
    Map<String, Object?>? fields, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // §11: no verbose logging in release builds.
    if (!_verbose && (level == LogLevel.debug || level == LogLevel.info)) {
      return;
    }

    final safeFields = _redactor.redact(fields);
    final buffer = StringBuffer(event);
    if (safeFields.isNotEmpty) {
      buffer.write(' ');
      buffer.write(
          safeFields.entries.map((e) => '${e.key}=${e.value}').join(' '));
    }

    final message = buffer.toString();

    // The exception *type* is diagnostic; its message may embed PII (a failed
    // request body, a depot name), so it is redacted like any other value.
    final safeError =
        error == null ? null : _redactor.redactValue('error', error);

    developer.log(
      message,
      name: 'isi.${level.name}',
      level: _severity(level),
      error: safeError,
      // §10: stack traces are development-only.
      stackTrace: _verbose ? stackTrace : null,
    );

    // `developer.log` reaches the VM service — DevTools' Logging view and the
    // IDE — but **not** the `flutter run` terminal, which only shows stdout.
    // Mirroring to [debugPrint] is what makes these records visible where
    // people actually watch them while debugging a device.
    //
    // Same redacted string, so the terminal copy can never leak more than the
    // structured one, and only in verbose (non-release) builds, keeping
    // SECURITY.md §11 intact.
    if (_verbose) {
      debugPrint('[isi.${level.name}] $message'
          '${safeError == null ? '' : ' error=$safeError'}');
      // Only for errors, and only in development: a stack trace is the whole
      // reason an unexpected failure is diagnosable at all, but it is noise
      // everywhere else.
      if (stackTrace != null && level == LogLevel.error) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  /// Maps to `dart:developer` levels, which follow `package:logging` values.
  int _severity(LogLevel level) => switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      };
}

/// Redacts values that `docs/skills/security.md` §10 forbids logging.
///
/// Two independent passes, because either alone is insufficient:
///  1. **Key-name matching** — catches `token`, `email`, `depotName`, …
///     regardless of the value's shape.
///  2. **Value-shape matching** — catches a JWT or an email address that
///     arrived under an innocuous key (e.g. `{'v': 'a.b.c'}`).
///
/// Bias is deliberately toward over-redaction: losing a debuggable value is
/// recoverable, leaking depot PII or a token into a log sink is not.
class LogRedactor {
  const LogRedactor();

  static const String placeholder = '***REDACTED***';

  /// Key fragments that imply a §10-forbidden value. Matched case-insensitively
  /// against the whole key, so `refreshToken` and `refresh_token` both hit.
  ///
  /// `code` is deliberately absent: §10 explicitly *allows* response and error
  /// codes, and they are the primary diagnostic signal for network failures.
  static final RegExp _sensitiveKey = RegExp(
    r'(pass|pwd|secret|token|jwt|bearer|auth|apikey|api_key|credential'
    r'|email|mail|phone|mobile|msisdn|contact'
    r'|depot|owner|shop|address|province|district'
    r'|revenue|price|amount|total|credit|balance|salary|discount'
    r'|lat|lng|longitude|latitude|geo|coord'
    // Personnel identifiers. An employee ID is the sign-in identifier printed
    // on a badge and a payslip: it names a specific person, and its short
    // digit run (`ADM000001`) slips under the value-shape rules, so only the
    // key check catches it.
    r'|employee|personnel|staff|badge'
    r'|name|user|account|session|device_id|deviceid)',
    caseSensitive: false,
  );

  /// Keys whose values are correlation identifiers: opaque, server-minted, and
  /// tied to a request rather than to a person.
  ///
  /// These skip the *value-shape* pass only. They have to, because a trace id
  /// like `0HNNOE4PB87QD:00000001` trips [_longDigitRun] and comes out as
  /// `***REDACTED***` — which defeats the entire point of emitting it. §10
  /// allows these for the same reason it allows response and error codes: the
  /// id identifies a request in a server log, and support cannot find the call
  /// behind a bug report without it.
  ///
  /// Anchored and exhaustive, so this widens nothing by accident: a key must be
  /// exactly one of these to qualify, and the sensitive-key pass still runs
  /// first.
  static final RegExp _correlationKey = RegExp(
    r'^(correlationid|correlation_id|traceid|trace_id|requestid|request_id)$',
    caseSensitive: false,
  );

  /// A three-segment dot-delimited base64url blob — i.e. a JWT.
  static final RegExp _jwtValue = RegExp(
    r'^[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}$',
  );

  static final RegExp _emailValue = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );

  /// Seven or more consecutive digits — a phone number, account number, or an
  /// MSISDN. Short digit runs (status codes, counts, attempts) are preserved.
  static final RegExp _longDigitRun = RegExp(r'\d{7,}');

  /// Returns a copy of [fields] safe to emit. Never returns null, so callers
  /// don't branch on emptiness.
  Map<String, Object?> redact(Map<String, Object?>? fields) {
    if (fields == null || fields.isEmpty) return const {};
    return {
      for (final entry in fields.entries)
        entry.key: redactValue(entry.key, entry.value),
    };
  }

  /// Redacts a single [value] given its [key]. Exposed so callers logging a
  /// bare exception object get the same value-shape protection.
  Object? redactValue(String key, Object? value) {
    if (value == null) return null;

    // The correlation allowlist is checked *before* the sensitive-key pass,
    // not after, because `correlationId` matches that pass by accident: it
    // contains "lat", the fragment meant for `latitude`. Ordering it second
    // would silently mask the field regardless of the exemption — which is
    // exactly what happened first time round.
    final isCorrelationId = _correlationKey.hasMatch(key);

    if (!isCorrelationId && _sensitiveKey.hasMatch(key)) return placeholder;

    // Recurse so nested payloads can't smuggle PII past the key check.
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': redactValue('${entry.key}', entry.value),
      };
    }
    if (value is Iterable) {
      return value.map((e) => redactValue(key, e)).toList();
    }

    // Booleans and small numbers are shape-safe; a huge int could be an account
    // number, so it still goes through the string check below.
    if (value is bool) return value;

    final text = value.toString();

    // Correlation ids are exempt from the digit-run rule, but never from the
    // token and address rules — if something that looks like a JWT or an
    // e-mail arrives under `traceId`, that is a bug worth redacting, not an
    // identifier worth printing.
    if (isCorrelationId) {
      return _jwtValue.hasMatch(text) || _emailValue.hasMatch(text)
          ? placeholder
          : value;
    }

    if (_jwtValue.hasMatch(text)) return placeholder;
    if (_emailValue.hasMatch(text)) return placeholder;
    if (_longDigitRun.hasMatch(text)) return placeholder;
    return value;
  }
}
