import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/interceptors/api_headers_interceptor.dart';
import 'package:steelforce/core/utils/typedefs.dart';

// TODO(release-gate): integration logging for the plan visit calls
// (ad hoc, check-in, inventory photos, check-out). Prints only in debug
// builds; delete once the flow is verified end to end on the real backend.

/// Boxed console output for one plan visit request, in debug builds only.
///
/// Filter the debug console on `PLAN VISIT` to see each attempt as blocks:
/// what was sent, then what came back — and for a refusal, what the code
/// usually means. Never prints coordinates, photo names, notes or tokens:
/// only presence, counts, sizes, ids and codes.
abstract final class PlanVisitDebugLog {
  static const _width = 76;

  /// Runs [send], printing a REQUEST block before it and a result block
  /// after. Whatever [send] throws is printed and rethrown unchanged.
  static Future<T> trace<T>({
    required String step,
    required String method,
    required String path,
    required List<String> Function() rows,
    required Future<({Response<DataMap> res, T value})> Function() send,
  }) async {
    if (kDebugMode) _block('$step · REQUEST', ['$method $path', ...rows()]);
    final clock = Stopwatch()..start();
    try {
      final (:res, :value) = await send();
      _success(step, res, clock.elapsedMilliseconds);
      return value;
    } on DioException catch (e) {
      _failure(step, e, clock.elapsedMilliseconds);
      rethrow;
    } on Object catch (e) {
      _block('$step · ✗ UNREADABLE (${clock.elapsedMilliseconds}ms)', [
        row('error', e.runtimeType.toString()),
        row('hint', 'The server answered 2xx but the body did not parse.'),
      ]);
      rethrow;
    }
  }

  /// One aligned `key  value` line.
  static String row(String key, Object? value) =>
      '${key.padRight(16)}${value ?? '-'}';

  /// The photos as count, size and type — never their names.
  static List<String> photoRows(List<String> paths) => [
        row('photos', paths.length),
        for (final (i, path) in paths.indexed)
          row('  #${i + 1}', '${_kb(path)} · ${_type(path)}'),
      ];

  static void _success(String step, Response<DataMap> res, int ms) {
    final data = res.data?['data'];
    final map = data is Map ? data : const {};
    _block('$step · ✓ ${res.statusCode} OK (${ms}ms)', [
      row('correlationId', _correlation(res.requestOptions)),
      if (map['id'] != null) row('data.id', map['id']),
      if (map['status'] != null) row('data.status', map['status']),
      if (map.isNotEmpty) row('data keys', map.keys.join(', ')),
    ]);
  }

  static void _failure(String step, DioException e, int ms) {
    final error = ApiError.fromDio(e);
    final code = error.serverCode ?? error.code;
    final transport = e.response?.statusCode?.toString() ?? e.type.name;
    _block('$step · ✗ $transport $code (${ms}ms)', [
      row('correlationId',
          error.correlationId ?? _correlation(e.requestOptions)),
      if (error.message != null) row('message', error.message),
      if (error.detail != null) row('detail', error.detail),
      for (final MapEntry(:key, :value) in error.fieldErrors.entries)
        row('field $key', value.join('; ')),
      if (error.details case final details? when details.isNotEmpty)
        row('details', details),
      if (_hint(code, e) case final hint?) row('hint', hint),
    ]);
  }

  static String? _hint(String code, DioException e) => switch (code) {
        'PLAN_STATUS_CONFLICT' =>
          'The visit is not in the right status for this step '
              '(check-in needs Planned/Draft; photos and check-out need '
              'CheckedIn). Pull to refresh.',
        'PLAN_NOT_TODAY' => 'Only today\'s visits can be started.',
        'PLAN_NOT_FOUND' => 'No such plan id for this rep.',
        'PLAN_CHECK_IN_REASON_REQUIRED' =>
          'Outside the depot radius: send reason + description.',
        'PLAN_INVENTORY_PHOTO_REQUIRED' =>
          'Check-out needs at least one inventory photo uploaded first.',
        'PLAN_INVENTORY_PHOTO_LIMIT' =>
          'The visit already holds the most photos — the app treats this '
              'as done and moves on to check-out.',
        'PLAN_INVENTORY_PHOTO_INVALID' ||
        'PLAN_CHECK_IN_PHOTO_INVALID' =>
          'Photo refused: JPG or PNG only.',
        'PLAN_INVENTORY_PHOTO_TOO_LARGE' ||
        'PLAN_CHECK_IN_PHOTO_TOO_LARGE' =>
          'Photo too large (limit 10 MB each).',
        'PLAN_OUTLET_NOT_FOUND' =>
          'Ad hoc: unknown, deleted or not visible outlet — check '
              'outletType and depotCode / nonDepotId.',
        'PLAN_ALREADY_VISITED_TODAY' =>
          'Ad hoc: the outlet is already on today (details.planId).',
        'PLAN_AD_HOC_LIMIT_REACHED' => 'Ad hoc: daily limit (details.limit).',
        'PLAN_ID_IN_USE' => 'Ad hoc: visitId clashes; the next tap sends a '
            'new one.',
        'PLAN_EMPLOYEE_CODE_REQUIRED' =>
          'The signed-in user is not a current sales employee.',
        _ when e.type == DioExceptionType.connectionError =>
          'No connection to the server.',
        _ when e.type == DioExceptionType.sendTimeout =>
          'Upload timed out — large photos on a slow network?',
        _ => null,
      };

  static String _correlation(RequestOptions options) =>
      '${options.headers[ApiHeadersInterceptor.correlationHeader] ?? '-'}';

  static String _kb(String path) {
    try {
      return '${(File(path).lengthSync() / 1024).toStringAsFixed(0)} KB';
    } on Object {
      return 'missing file';
    }
  }

  static String _type(String path) =>
      path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  static void _block(String title, List<String> lines) {
    if (!kDebugMode) return;
    debugPrint([
      '┌─ PLAN VISIT · $title '.padRight(_width, '─'),
      for (final line in lines) '│ $line',
      '└'.padRight(_width, '─'),
    ].join('\n'));
  }
}
