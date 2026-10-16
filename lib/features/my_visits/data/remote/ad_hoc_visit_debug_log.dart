import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:steelforce/core/network/api/api_error.dart';

// TODO(release-gate): temporary integration logging for
// `POST /mobile/visits/ad-hoc` — delete this file and its call sites once the
// endpoint is verified end to end. Every entry point is a no-op outside debug
// builds, and nothing here prints a depot's name, contact, phone or address.

/// Boxed, human-readable console output for the ad hoc visit integration.
///
/// Filter the debug console on `AD HOC` to see one attempt as a single block:
/// who asked, what was sent, what came back, and — for a refusal — what the
/// code usually means.
abstract final class AdHocVisitDebugLog {
  static const _width = 72;

  /// Why this attempt is happening, and which depot it is for.
  static void attempt({
    required String trigger,
    required String depotId,
    required String sk,
    required String clientRequestId,
  }) {
    _block('ATTEMPT · $trigger', [
      _row('depotId', depotId),
      _row('sk', sk),
      _row('clientRequestId', clientRequestId),
    ]);
  }

  static void request(String method, String path, Map<String, dynamic> body) {
    _block('REQUEST', [
      '$method $path',
      ..._json(body),
    ]);
  }

  /// Deliberately a summary rather than the raw body: the success payload
  /// carries the depot's full contact record.
  static void success({
    required int? status,
    required int elapsedMs,
    required bool created,
    required String stopId,
    required String depotId,
    required int sequence,
    required DateTime visitDate,
  }) {
    _block('✓ ${status ?? '-'} OK (${elapsedMs}ms)', [
      _row('created', created ? 'true (new visit)' : 'false (replay)'),
      _row('stopId', stopId),
      _row('depotId', depotId),
      _row('sequence', '$sequence'),
      _row('visitDate', visitDate.toIso8601String().split('T').first),
    ]);
  }

  static void failure({
    required ApiError error,
    required String transport,
    required int elapsedMs,
    required String sk,
    Object? body,
  }) {
    _block('✗ $transport ${error.code} (${elapsedMs}ms)', [
      _row('correlationId', error.correlationId ?? '-'),
      if (error.detail != null) _row('detail', error.detail!),
      if (_hint(error.code, sk) case final hint?) _row('hint', hint),
      if (body != null) ...['body', ..._json(body)],
    ]);
  }

  static void unreadable(String message) {
    _block('✗ 200 UNREADABLE BODY', [_row('parser', message)]);
  }

  static String? _hint(String code, String sk) => switch (code) {
        ApiErrorCodes.visitDepotNotFound =>
          'The server has no depot whose SAP code is "$sk". Check the '
              "depot's sapCustomerId against the backend's sapDepotsCode.",
        ApiErrorCodes.visitDepotCodeAmbiguous =>
          'More than one depot on the server has SAP code "$sk".',
        ApiErrorCodes.visitDepotNotAccessible =>
          'The depot exists but is outside this rep\'s scope.',
        ApiErrorCodes.visitDepotAlreadyPlanned =>
          'Already on today\'s Call Plan — the app opens that stop.',
        ApiErrorCodes.visitAdHocAlreadyExists =>
          'Already added as an ad hoc visit today — the app opens that stop.',
        ApiErrorCodes.visitAdHocDateInvalid =>
          'visitDate must be null; the server owns the day.',
        ApiErrorCodes.visitRepNotAuthorized ||
        ApiErrorCodes.visitTerritoryNotAssigned ||
        ApiErrorCodes.visitAdHocNotAllowed =>
          'Rep setup on the server, not the app.',
        _ => null,
      };

  static String _row(String key, String value) => '${key.padRight(16)}$value';

  static List<String> _json(Object? value) =>
      const JsonEncoder.withIndent('  ', _fallback).convert(value).split('\n');

  static Object? _fallback(Object? value) => value.toString();

  static void _block(String title, List<String> lines) {
    if (!kDebugMode) return;
    final head = '┌─ AD HOC VISIT · $title ';
    debugPrint([
      head.padRight(_width, '─'),
      for (final line in lines) '│ $line',
      '└'.padRight(_width, '─'),
    ].join('\n'));
  }
}
