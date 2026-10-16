import 'package:flutter/foundation.dart';
import 'package:steelforce/core/network/api/api_error.dart';

// TODO(release-gate): temporary integration logging for
// `GET /mobile/depots/{id}/stop-information` — delete this file and its call
// sites once the endpoint is verified end to end. Every entry point is a no-op
// outside debug builds, and nothing here prints the outlet's name, contact,
// phone, address or credit figures.

/// Boxed console output for the stop screen's outlet-details fetch.
///
/// The stop screen shows one banner — "Outlet details could not be loaded" —
/// for a 404, a 403, a 500 and an unreadable body alike. Filter the debug
/// console on `STOP INFO` to see which one it actually was.
abstract final class StopInformationDebugLog {
  static const _width = 72;

  static void request(String depotId, String path) {
    _block('REQUEST', [_row('depotId', depotId), 'GET $path']);
  }

  static void success({required int elapsedMs, required String code}) {
    _block('✓ 200 OK (${elapsedMs}ms)', [_row('outlet code', code)]);
  }

  static void failure({required ApiError error, required int elapsedMs}) {
    final status = error.statusCode;
    _block('✗ ${status ?? '-'} ${error.code} (${elapsedMs}ms)', [
      _row('correlationId', error.correlationId ?? '-'),
      if (error.detail != null) _row('detail', error.detail!),
      if (_hint(status) case final hint?) _row('hint', hint),
    ]);
  }

  static void unreadable({required int elapsedMs, required Object error}) {
    _block('✗ 200 UNREADABLE BODY (${elapsedMs}ms)', [
      _row('parser', '${error.runtimeType}: $error'),
      _row('hint', 'The server answered, but not in the documented shape.'),
    ]);
  }

  static String? _hint(int? status) => switch (status) {
        404 => 'No outlet with this id for this rep — either it does not '
            'exist on the server or it is outside the rep\'s entitlement. '
            'Check the id is the server GUID from the route sync.',
        403 => 'The rep\'s role lacks `customers.read`, which this endpoint '
            'requires. Role setup on the server, not the app.',
        401 => 'The session was rejected. Sign in again.',
        final s? when s >= 500 => 'Server error — give the backend team the '
            'correlationId.',
        _ => null,
      };

  static String _row(String key, String value) => '${key.padRight(16)}$value';

  static void _block(String title, List<String> lines) {
    if (!kDebugMode) return;
    final head = '┌─ STOP INFO · $title ';
    debugPrint([
      head.padRight(_width, '─'),
      for (final line in lines) '│ $line',
      '└'.padRight(_width, '─'),
    ].join('\n'));
  }
}
