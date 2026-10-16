import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';

/// `GET /mobile/pricing/depots/{depotId}`.
abstract interface class PricingRemoteDataSource {
  /// One request for every material on the quotation.
  ///
  /// The endpoint's `materials` parameter repeats, so this batches rather than
  /// issuing one call per line — a rep adding an eighth material should not
  /// cost an eighth round trip.
  Future<List<DataMap>> fetchPrices({
    required String depotId,
    required List<String> materials,
  });
}

class ApiPricingRemoteDataSource implements PricingRemoteDataSource {
  const ApiPricingRemoteDataSource(this._client, this._logger);

  final Dio _client;
  final AppLogger _logger;

  /// The list under `data`.
  ///
  /// **Was `'prices'`, which silently returned nothing.** `ApiListEnvelope`
  /// answers `data[key]`, and an absent key is treated as an empty result set
  /// rather than an error — deliberately, because a genuinely empty list is a
  /// normal answer. So the wrong key produced exactly what "this depot has
  /// no prices" produces: zero rows, HTTP 200, no log, no exception. Every
  /// quotation line rendered as unpriced and nothing anywhere said why.
  ///
  /// The name is pinned here, next to the sample response it comes from
  /// (`docs/feature/order/pricing/api/mobile.md` §200), so the next person
  /// changing it has the contract in view.
  static const String _itemsKey = 'items';

  @override
  Future<List<DataMap>> fetchPrices({
    required String depotId,
    required List<String> materials,
  }) async {
    final cleanedMaterials = materials
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    if (cleanedMaterials.isEmpty) return const [];

    final path = ApiEndpoints.depotPricingEndpoint(depotId);
    final stopwatch = Stopwatch()..start();

    _dumpRequestForDebugging(path, depotId, cleanedMaterials);

    try {
      final res = await _client.get<Object?>(
        path,
        // A `List` value is serialised as a repeated key by Dio's default
        // `ListFormat.multi` — `?materials=A&materials=B`, which is the
        // contract. Joining them with a comma would arrive as one material
        // named "A,B" and price nothing.
        queryParameters: {'materials': cleanedMaterials},
        options: Options(listFormat: ListFormat.multi),
      );

      final items = ApiListEnvelope.fromBody(res.data, key: _itemsKey).items;
      _dumpSuccessForDebugging(
        path,
        cleanedMaterials,
        res.statusCode,
        stopwatch.elapsedMilliseconds,
        res.data,
        items,
      );

      _logSourceDiagnostics(res.data,
          requested: cleanedMaterials, received: items);
      return items;
    } on DioException catch (e) {
      _dumpErrorForDebugging(
        path,
        depotId,
        cleanedMaterials,
        e,
        stopwatch.elapsedMilliseconds,
      );

      _logger.warning('pricing.fetch_failed', fields: {
        'status': e.response?.statusCode,
        'code': ApiError.fromDio(e).code,
        'materials': cleanedMaterials.length,
      });
      throw ApiException(ApiError.fromDio(e));
    }
  }

  /// Reads the response's own `source` block and says when it disagrees with
  /// what was asked for.
  ///
  /// The API publishes three counters for exactly this purpose, and two of them
  /// describe failures that are otherwise invisible:
  ///
  ///  * **`recordsUnmapped > 0`** — the doc is explicit: *"Non-zero means the
  ///    field-name contract is wrong."* Those rows arrive with `price: 0` and a
  ///    blank currency, so without this they would render as free stock.
  ///  * **`erpAnswered: false`** — SAP did not answer. That is a different
  ///    statement from "this depot has no prices", and the doc requires the
  ///    two never render the same way.
  ///
  /// Counts and flags only — never a price. `docs/skills/security.md` §10 keeps
  /// revenue data out of logs, and these are the diagnostics that stay legal in
  /// a release build.
  void _logSourceDiagnostics(
    Object? body, {
    required List<String> requested,
    required List<DataMap> received,
  }) {
    final source = (body is Map ? body['data'] : null) is Map
        ? ((body as Map)['data'] as Map)['source']
        : null;

    final unmapped =
        source is Map ? (source['recordsUnmapped'] as num?)?.toInt() ?? 0 : 0;
    final erpAnswered =
        source is Map ? source['erpAnswered'] as bool? ?? true : true;

    if (!erpAnswered) {
      _logger.warning('pricing.erp_did_not_answer', fields: {
        'materials': requested.length,
      });
    }
    if (unmapped > 0) {
      // Loud on purpose. The server log names the fields SAP actually sent; a
      // mobile-side warning is what makes somebody go and read it.
      _logger.error('pricing.unmapped_rows', fields: {
        'unmapped': unmapped,
        'mapped': received.length,
      });
    }

    _logger.info('pricing.fetched', fields: {
      'requested': requested.length,
      'returned': received.length,
      'unmapped': unmapped,
    });
  }

  /// Prints the raw pricing response to the console.
  ///
  /// TODO(release-gate): debug-only. This must not ship enabled.
  ///
  /// ## Why it is fenced the way it is
  ///
  /// A price **is** revenue data, and `docs/skills/security.md` §10 forbids
  /// logging it — so this cannot go through [AppLogger], whose `LogRedactor`
  /// would replace every `price` field with `***REDACTED***` and make the dump
  /// useless anyway.
  ///
  /// `kDebugMode` is a compile-time constant, so the entire body is
  /// **tree-shaken out of a release build** rather than merely skipped at
  /// runtime. That is what makes a deliberate §10 exception acceptable here:
  /// there is no build in which it can leak.
  ///
  /// It exists because the pricing response contract is still unverified
  /// (`docs/feature/order/pricing/sap-integration.md`) and the failure mode is
  /// silent — a wrong field name returns HTTP 200 with an empty list, which is
  /// indistinguishable from a depot who has no prices. Seeing the actual
  /// body is the only way to tell those apart from the handset.
  void _dumpRequestForDebugging(
    String path,
    String depotId,
    List<String> materials,
  ) {
    if (!kDebugMode) return;

    debugPrint('┌── [PRICING REQUEST] ${'─' * 42}');
    debugPrint('│ Endpoint: GET $path');
    debugPrint('│ Depot ID: $depotId');
    debugPrint('│ Materials (${materials.length}): ${materials.join(', ')}');
    debugPrint(
        '│ Query Parameters: {materials: [${materials.join(', ')}]} (ListFormat.multi)');
    debugPrint('└${'─' * 64}');
  }

  void _dumpSuccessForDebugging(
    String path,
    List<String> materials,
    int? statusCode,
    int elapsedMs,
    Object? body,
    List<DataMap> items,
  ) {
    if (!kDebugMode) return;

    debugPrint('┌── [PRICING SUCCESS] ${'─' * 42}');
    debugPrint('│ GET $path');
    debugPrint('│ Status: $statusCode OK ($elapsedMs ms)');
    debugPrint(
        '│ Materials requested (${materials.length}): ${materials.join(', ')}');
    debugPrint('│ Items returned: ${items.length}');
    for (final item in items) {
      debugPrint('│   • Material: ${item['material']} => '
          'Price: ${item['price']} ${item['currency'] ?? ''} '
          'per ${item['pricingUnit'] ?? 1} ${item['conditionUnit'] ?? ''} '
          '(Valid: ${item['validFrom']} ~ ${item['validTo']})');
    }
    debugPrint('│ Full Response Body:');
    _printFormattedBody(body);
    debugPrint('└${'─' * 64}');
  }

  void _dumpErrorForDebugging(
    String path,
    String depotId,
    List<String> materials,
    DioException e,
    int elapsedMs,
  ) {
    if (!kDebugMode) return;

    final apiError = ApiError.fromDio(e);
    final response = e.response;
    final statusCode = response?.statusCode;

    debugPrint('┌── [PRICING ERROR] ${'─' * 44}');
    debugPrint('│ GET $path');
    debugPrint('│ Failed URL: ${e.requestOptions.uri}');
    debugPrint('│ Status Code: $statusCode ($elapsedMs ms)');
    debugPrint('│ Depot ID: $depotId');
    debugPrint(
        '│ Materials requested (${materials.length}): ${materials.join(', ')}');
    debugPrint('│ Dio Error Type: ${e.type.name}');
    debugPrint('│ Platform Error Code: ${apiError.code}');
    if (apiError.correlationId != null) {
      debugPrint('│ Correlation / Trace ID: ${apiError.correlationId}');
    }
    if (e.message != null && e.message!.isNotEmpty) {
      debugPrint('│ Error Message: ${e.message}');
    }

    final responseBody = response?.data;
    if (responseBody != null) {
      debugPrint('│ Server Response Body:');
      _printFormattedBody(responseBody);
    } else {
      debugPrint('│ Server Response Body: <empty>');
    }

    if (apiError.code == 'Sap.ApiError' || statusCode == 500) {
      debugPrint('│ ℹ️ Diagnosis:');
      debugPrint(
          '│   Backend reached SAP GetPriceByPaging, but SAP returned an error (5xx)');
      debugPrint(
          '│   or the SAP sales area / condition records for this depot could not be read.');
      debugPrint(
          '│   Check server logs with correlationId="${apiError.correlationId}".');
    }
    debugPrint('└${'─' * 64}');
  }

  void _printFormattedBody(Object? body) {
    try {
      Object? decoded = body;
      if (body is String) {
        try {
          decoded = jsonDecode(body);
        } catch (_) {
          decoded = body;
        }
      }
      if (decoded is Map || decoded is List) {
        const encoder = JsonEncoder.withIndent('  ');
        for (final line in encoder.convert(decoded).split('\n')) {
          debugPrint('│   $line');
        }
      } else {
        for (final line in decoded.toString().split('\n')) {
          debugPrint('│   $line');
        }
      }
    } catch (_) {
      debugPrint('│   (unencodable) $body');
    }
  }
}
