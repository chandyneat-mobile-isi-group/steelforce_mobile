import 'package:flutter/foundation.dart';

/// Development-only trace output. Do not pass phone numbers, OTPs, passwords,
/// access tokens, Firebase ID tokens, or reset tokens as [message].
void debugTrace(String scope, String message) {
  if (!kDebugMode) return;
  debugPrint('[$scope] $message');
}

/// Structured debug-only trace used by the depot registration and camera
/// flows. Values are limited to the safe metadata supplied by call sites;
/// identifiers must go through [id] and payloads must never be logged.
class DebugTrace {
  const DebugTrace(this.scope);

  final String scope;

  void begin(String label) => _write('BEGIN', label, const {});

  void step(String stage, String message,
          [Map<String, Object?> fields = const {}]) =>
      _write('STEP', '$stage: $message', fields);

  void send(String stage, String message,
          [Map<String, Object?> fields = const {}]) =>
      _write('SEND', '$stage: $message', fields);

  void ok(String stage, String message,
          [Map<String, Object?> fields = const {}]) =>
      _write('OK', '$stage: $message', fields);

  void warn(String stage, String message,
          [Map<String, Object?> fields = const {}]) =>
      _write('WARN', '$stage: $message', fields);

  void fail(String stage, String message,
          [Map<String, Object?> fields = const {}]) =>
      _write('FAIL', '$stage: $message', fields);

  void _write(String level, String message, Map<String, Object?> fields) {
    if (!kDebugMode) return;
    final metadata = fields.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint(
        '[$scope] $level $message${metadata.isEmpty ? '' : ' $metadata'}');
  }

  /// Returns a short one-way process hash for correlating an ID in a single
  /// debug run without printing the original business identifier.
  static String id(Object? value) {
    if (value == null) return 'none';
    final hash = value.toString().hashCode.toRadixString(16);
    return '#${hash.length > 6 ? hash.substring(hash.length - 6) : hash}';
  }

  /// Renders only field/key names, never the values associated with them.
  static String names(Iterable<Object?> values) =>
      '[${values.map((value) => value.toString()).join(',')}]';

  static String yesNo(bool value) => value ? 'yes' : 'no';
}
