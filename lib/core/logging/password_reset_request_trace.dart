import 'dart:convert';

import 'package:steelforce/core/logging/debug_trace.dart';

/// Correlated request/response logging for password reset, printed as framed
/// blocks so one call reads at a glance in a busy console:
///
/// ```
/// ══════ [PR-0001] POST /api/v1/auth/forgot-password/phone/start ══════
///   Request body:
///     {
///       "phoneNumber": "+855•••••678"
///     }
/// ══════ [PR-0001] Result ═════════════════════════════════════════════
///   Outcome     : ✗ FAILED
///   Status      : 400 Bad Request · 346 ms · badResponse
///   Server code : AUTH_PHONE_CHANNEL_DISABLED
///   Response body:
///     { … }
/// ═════════════════════════════════════════════════════════════════════
/// ```
///
/// Bodies are printed in full **except** the values that must never reach a
/// log (`docs/skills/security.md` §10): phone numbers keep only their ends,
/// tokens only their length and last four characters, and passwords and
/// codes only their length. Digit runs long enough to be a phone number are
/// masked inside free text too. Debug builds only, via [debugTrace].
class PasswordResetRequestTrace {
  PasswordResetRequestTrace._(this.id, this.method, this.path)
      : _watch = Stopwatch()..start();

  static int _sequence = 0;

  /// Width of a rule line, in characters.
  static const _width = 72;

  /// The longest a non-JSON body (an HTML error page) is printed.
  static const _maxTextBody = 2000;

  final String id;
  final String method;
  final String path;
  final Stopwatch _watch;

  /// [requestBody] is the payload as sent; without one (a Firebase SDK call,
  /// an empty POST) only [requestFields] are listed.
  factory PasswordResetRequestTrace.start({
    required String method,
    required String path,
    Iterable<String> requestFields = const [],
    Object? requestBody,
  }) {
    final sequence = ++_sequence;
    final id = 'PR-${sequence.toString().padLeft(4, '0')}';
    final trace = PasswordResetRequestTrace._(id, method, path);
    _print([
      _rule('[$id] $method $path'),
      if (requestBody != null)
        ..._body('Request body', requestBody)
      else
        _row('Request', _fields(requestFields)),
    ]);
    return trace;
  }

  void response({
    required int? status,
    Iterable<String> responseFields = const [],
    Object? body,
  }) {
    _watch.stop();
    _print([
      _rule('[$id] Result'),
      _row('Request', '$method $path'),
      _row('Outcome', '✓ OK'),
      _row('Status', _status(status, null)),
      if (body != null)
        ..._body('Response body', body)
      else
        _row('Response', _fields(responseFields)),
      _rule(),
    ]);
  }

  /// [errorCode], [serverCode], [message], [correlationId], [fieldErrors]
  /// and [body] are the server's answer, when there was one.
  void failure({
    required int? status,
    required String type,
    String? errorCode,
    String? serverCode,
    String? message,
    String? correlationId,
    Iterable<String> fieldErrors = const [],
    Object? body,
  }) {
    _watch.stop();
    _print([
      _rule('[$id] Result'),
      _row('Request', '$method $path'),
      _row('Outcome', '✗ FAILED'),
      _row('Status', _status(status, type)),
      if (errorCode != null) _row('Error code', errorCode),
      if (serverCode != null && serverCode != errorCode)
        _row('Server code', serverCode),
      if (message != null && message.trim().isNotEmpty)
        _row('Message', _redact(message.trim())),
      if (fieldErrors.isNotEmpty) _row('Invalid', _fields(fieldErrors)),
      if (correlationId != null) _row('Correlation', correlationId),
      if (body != null) ..._body('Response body', body),
      _rule(),
    ]);
  }

  void event(String name, {Map<String, Object?> fields = const {}}) {
    final metadata = fields.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugTrace(
      'password-reset',
      '[$id] ··· $name after ${_watch.elapsedMilliseconds} ms'
          '${metadata.isEmpty ? '' : '  $metadata'}',
    );
  }

  /// One debugPrint, so the block is never split by other output.
  static void _print(List<String> lines) =>
      debugTrace('password-reset', '\n${lines.join('\n')}');

  static String _rule([String? title]) {
    if (title == null) return '═' * _width;
    final head = '══════ $title ';
    return head.length >= _width ? head : head.padRight(_width, '═');
  }

  static String _row(String label, String value) =>
      '  ${label.padRight(11)} : $value';

  /// [body] as indented JSON, masked; plain text when it is not JSON.
  static List<String> _body(String label, Object body) {
    final String text;
    if (body is Map || body is List) {
      text = const JsonEncoder.withIndent('  ').convert(_mask(body));
    } else {
      final raw = _redact(body.toString());
      text = raw.length > _maxTextBody
          ? '${raw.substring(0, _maxTextBody)}… (${raw.length} chars)'
          : raw;
    }
    return ['  $label:', for (final line in text.split('\n')) '    $line'];
  }

  /// A copy of [value] with every value that must not be logged masked.
  static Object? _mask(Object? value, [String key = '']) {
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key.toString(): _mask(e.value, e.key.toString()),
      };
    }
    if (value is List) return [for (final v in value) _mask(v, key)];
    if (value is! String) {
      // Numbers, bools, null — and anything else JSON cannot encode as is.
      return value == null || value is num || value is bool
          ? value
          : value.toString();
    }
    final k = key.toLowerCase();
    if (k.contains('password') ||
        k.contains('secret') ||
        k == 'otp' ||
        k == 'smscode') {
      return '«hidden · ${value.length} chars»';
    }
    if (k.contains('token') || k.contains('credential')) {
      final tail =
          value.length > 8 ? ' · …${value.substring(value.length - 4)}' : '';
      return '«token · ${value.length} chars$tail»';
    }
    if (k.contains('phone')) return maskPhone(value);
    // Identifiers are hex and digits; masking "digit runs" would mangle them.
    if (k.endsWith('id')) return value;
    return _redact(value);
  }

  /// `+85512345678` → `+855•••••678`.
  static String maskPhone(String phone) => phone.length <= 7
      ? '•' * phone.length
      : '${phone.substring(0, 4)}${'•' * (phone.length - 7)}'
          '${phone.substring(phone.length - 3)}';

  String _status(int? status, String? type) => [
        status == null ? 'no response' : '$status ${_reason(status)}'.trim(),
        '${_watch.elapsedMilliseconds} ms',
        if (type != null) type,
      ].join(' · ');

  static String _reason(int status) => switch (status) {
        200 => 'OK',
        201 => 'Created',
        204 => 'No Content',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        403 => 'Forbidden',
        404 => 'Not Found',
        409 => 'Conflict',
        422 => 'Unprocessable Entity',
        429 => 'Too Many Requests',
        500 => 'Internal Server Error',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        _ => '',
      };

  /// Masks anything shaped like a phone number in free text.
  static String _redact(String text) =>
      text.replaceAll(RegExp(r'\+?\d[\d\s-]{5,}\d'), '•••');

  static String _fields(Iterable<String> fields) {
    final safeFields = fields.toSet().toList()..sort();
    return safeFields.isEmpty
        ? '(no body)'
        : '${safeFields.join(', ')}  (values hidden)';
  }
}
