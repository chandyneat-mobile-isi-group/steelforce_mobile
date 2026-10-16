import 'package:flutter/foundation.dart';

/// A compact, aligned console tracer for following one flow while developing.
///
/// ## What this is, and is not
///
/// This is **not** [AppLogger]. That one is structured, redacting, and intended
/// to survive into release telemetry. This is a developer's console view: it
/// exists so a multi-step flow — open a draft, patch it, submit, upload
/// evidence — reads as a legible sequence in `flutter run` instead of forty
/// unaligned sentences.
///
/// ```text
/// ─────── depot registration ───────
///   ▸ DRAFT     resumed  id=01a0412a status=Draft fields=46
///   ✓ STEP      1/5 identity
///   ✗ STEP      2/5 address  missing: city · postalCode · geo
///   ↑ HTTP      POST /draft → 200
///   ✓ SUBMIT    depot=01a03189 queued=no
///   ↑ PHOTOS    sent=2 retry=0 rejected=1
///   ✗ ERROR     submit → DioException
/// ```
///
/// ## Release safety
///
/// Every method returns immediately unless [kDebugMode], so the strings are
/// never built and nothing reaches a release console (`feature-ui-standard.md`
/// FS-SEC-3). Interpolation still happens at the call site, so keep arguments
/// cheap — pass a count, not a joined list of a thousand rows.
///
/// ## What may be traced
///
/// Codes, counts, ids, status codes, durations, field *names*. **Never** field
/// values, names, phone numbers, addresses, GPS positions or money
/// (FS-SEC-2). A trace line ends up in screenshots and pasted bug reports.
class DebugTrace {
  const DebugTrace(this.channel);

  /// Short flow name, printed on every line so interleaved flows stay
  /// separable.
  final String channel;

  static const int _verbWidth = 9;

  /// Opens a visually distinct block. Use once, when a flow starts.
  void begin(String title) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('─────── $title ───────');
  }

  /// A step happened. Neutral.
  void step(String verb, String summary, [Map<String, Object?>? fields]) =>
      _line('▸', verb, summary, fields);

  /// A step completed as intended.
  void ok(String verb, String summary, [Map<String, Object?>? fields]) =>
      _line('✓', verb, summary, fields);

  /// Something went out over the wire, or up to the server.
  void send(String verb, String summary, [Map<String, Object?>? fields]) =>
      _line('↑', verb, summary, fields);

  /// Worth noticing but not a failure — a fallback taken, a value ignored.
  void warn(String verb, String summary, [Map<String, Object?>? fields]) =>
      _line('!', verb, summary, fields);

  /// The step did not succeed.
  void fail(String verb, String summary, [Map<String, Object?>? fields]) =>
      _line('✗', verb, summary, fields);

  void _line(
    String glyph,
    String verb,
    String summary,
    Map<String, Object?>? fields,
  ) {
    if (!kDebugMode) return;

    final padded = verb.toUpperCase().padRight(_verbWidth);
    final rendered = _fields(fields);
    // debugPrint rather than print: it is rate-limited, so a burst during a
    // page run is throttled instead of being dropped by the platform log.
    debugPrint('[$channel] $glyph $padded $summary$rendered');
  }

  static String _fields(Map<String, Object?>? fields) {
    if (fields == null || fields.isEmpty) return '';
    final parts = <String>[];
    for (final entry in fields.entries) {
      // A null field is absent, not the string "null" — it would otherwise
      // read as a value the server actually sent.
      if (entry.value == null) continue;
      parts.add('${entry.key}=${entry.value}');
    }
    return parts.isEmpty ? '' : '  ${parts.join(' ')}';
  }

  /// Shortens an identifier to its leading segment.
  ///
  /// A UUID is 36 characters and only its head is useful for correlating lines
  /// by eye; printing it whole pushes every following field off the screen.
  static String id(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value.length <= 10 ? value : '${value.substring(0, 8)}…';
  }

  /// Renders a list of names for a human — `city · postalCode · geo`.
  ///
  /// Field *names* only. Never their values.
  static String names(Iterable<String> values) {
    final list = values.toList();
    if (list.isEmpty) return '—';
    return list.join(' · ');
  }

  /// `yes` / `no`, which scan far better than `true` / `false` in a dense line.
  static String yesNo(bool value) => value ? 'yes' : 'no';
}
