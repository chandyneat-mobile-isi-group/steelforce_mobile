import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/interceptors/api_headers_interceptor.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_debug_log.dart';

// TODO(release-gate): integration logging for depot and Non-BP depot
// creation. Prints only in debug builds; delete with depot_draft_debug_log
// once registration is verified end to end on the real backend.

/// Boxed console output for `POST /mobile/depots`, in debug builds only.
///
/// Filter the debug console on `DEPOT · CREATE`: the request body one field
/// per line, then what came back. Personal data is masked exactly as
/// [DepotDraftDebugLog.mask] does — names, phones, email, street, notes and
/// coordinates print as `***`; codes, ids and statuses print in full.
abstract final class DepotCreateDebugLog {
  static const _width = 76;

  /// Runs [send], printing a REQUEST block before it and a result block
  /// after. Whatever [send] throws is printed and rethrown unchanged.
  static Future<Response<DataMap>> trace({
    required String path,
    required DataMap body,
    required Future<Response<DataMap>> Function() send,
  }) async {
    final title = body['depotType'] == MobileDepotKind.nonDepot.apiValue
        ? 'NON-BP DEPOT'
        : 'DEPOT';
    _block(title, 'REQUEST', [
      'POST $path',
      ...supplierRows(body),
      '── body ──',
      ...rows(DepotDraftDebugLog.mask(body)),
    ]);
    final clock = Stopwatch()..start();
    try {
      final res = await send();
      final data = res.data?['data'];
      final map = data is Map ? data : const {};
      _block(title, '✓ ${res.statusCode} (${clock.elapsedMilliseconds}ms)', [
        _row('correlationId', _correlation(res.requestOptions)),
        if (map['id'] != null) _row('data.id', map['id']),
        if (map['status'] != null) _row('data.status', map['status']),
        if (map['depotCode'] != null) _row('data.depotCode', map['depotCode']),
        if (map['suppliers'] case final Object suppliers)
          ...rows(suppliers, 'data.suppliers'),
        if (map['depots'] case final Object depots)
          ...rows(depots, 'data.depots'),
        if (map.isNotEmpty) _row('data keys', map.keys.join(', ')),
      ]);
      return res;
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);
      final code = error.serverCode ?? error.code;
      final transport = e.response?.statusCode?.toString() ?? e.type.name;
      _block(title, '✗ $transport $code (${clock.elapsedMilliseconds}ms)', [
        _row('correlationId',
            error.correlationId ?? _correlation(e.requestOptions)),
        if (error.message != null) _row('message', error.message),
        if (error.detail != null) _row('detail', error.detail),
        for (final MapEntry(:key, :value) in error.fieldErrors.entries)
          _row('field $key', value.join('; ')),
      ]);
      rethrow;
    }
  }

  /// Who supplies the outlet, first and on its own lines — SAP codes, so
  /// printed in full. A Depot names up to three suppliers (`suppliers`); a
  /// Non-BP depot buys through 1-20 depots (`depots`). A slot left empty is
  /// not sent at all, so it is spelled out here rather than just missing.
  @visibleForTesting
  static List<String> supplierRows(DataMap body) {
    if (body['depotType'] == MobileDepotKind.nonDepot.apiValue) {
      final depots = body['depots'] is List ? body['depots'] as List : const [];
      return [
        '── supplying depots (${depots.length}) ──',
        if (depots.isEmpty)
          _row('depots', 'none — the server needs 1 to 20')
        else
          for (final (i, code) in depots.indexed) _row('depots[$i]', code),
      ];
    }
    final suppliers =
        body['suppliers'] is Map ? body['suppliers'] as Map : const {};
    return [
      '── suppliers ──',
      for (final slot in const ['primary', 'secondary', 'tertiary'])
        _row(
          slot,
          switch (suppliers[slot]) {
            {'type': final type, 'code': final code} => '$type $code',
            _ => 'not sent',
          },
        ),
    ];
  }

  /// [value] flattened to `path  value` lines: `address.provinceCode  12`,
  /// `contacts[0].role  Owner`. An empty list or map prints as such.
  @visibleForTesting
  static List<String> rows(Object? value, [String path = '']) =>
      switch (value) {
        final Map<dynamic, dynamic> map when map.isNotEmpty => [
            for (final e in map.entries)
              ...rows(e.value, path.isEmpty ? '${e.key}' : '$path.${e.key}'),
          ],
        final List<dynamic> list when list.isNotEmpty => [
            for (final (i, item) in list.indexed) ...rows(item, '$path[$i]'),
          ],
        Map() => [_row(path, '{}')],
        List() => [_row(path, '[]')],
        _ => [_row(path, value)],
      };

  /// Aligned at 28, and never run into its value when the path is longer.
  static String _row(String key, Object? value) =>
      '${key.length < 28 ? key.padRight(28) : '$key '}${value ?? 'null'}';

  static String _correlation(RequestOptions options) =>
      '${options.headers[ApiHeadersInterceptor.correlationHeader] ?? '-'}';

  static void _block(String kind, String title, List<String> lines) {
    if (!kDebugMode) return;
    debugPrint([
      '┌─ $kind · CREATE · $title '.padRight(_width, '─'),
      for (final line in lines) '│ $line',
      '└'.padRight(_width, '─'),
    ].join('\n'));
  }
}
