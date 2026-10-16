import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/order/data/models/mobile_price_model.dart';
import 'package:steelforce/features/order/data/remote/pricing_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';

/// Serves scripted responses so the data source can be driven without a server.
/// Same shape as `test/core/middleware/auth_interceptor_test.dart`'s adapter.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
          Future<void>? cancelFuture) =>
      handler(options..let(requests.add));

  @override
  void close({bool force = false}) {}
}

extension _Let<T> on T {
  T let(void Function(T value) action) {
    action(this);
    return this;
  }
}

ResponseBody _json(Map<String, dynamic> body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// The §200 sample from `docs/feature/order/pricing/api/mobile.md`, verbatim.
///
/// Copied field for field rather than paraphrased: this file's entire job is to
/// fail when the published contract and the client disagree, and a paraphrase
/// would drift from the document it is supposed to be pinning.
Map<String, dynamic> _specResponse({
  List<Map<String, dynamic>>? items,
  int unmapped = 0,
  bool erpAnswered = true,
}) =>
    {
      'success': true,
      'message': 'Pricing retrieved successfully.',
      'data': {
        'items': items ??
            [
              {
                'material': '2400000466',
                'price': 100.0,
                'currency': 'USD',
                'conditionUnit': 'M',
                'pricingUnit': 1,
                'validFrom': '2026-09-01',
                'validTo': '9999-12-31',
                'raw': null,
              },
            ],
        'source': {
          'recordsReturned': items?.length ?? 1,
          'recordsUnmapped': unmapped,
          'erpAnswered': erpAnswered,
        },
      },
      'metadata': null,
      'traceId': '0HNOA7D1C66TK:00000001',
      'timestamp': '2026-09-04T04:16:30.6672159+00:00',
    };

void main() {
  late _ScriptedAdapter adapter;
  late ApiPricingRemoteDataSource source;

  void serve(Future<ResponseBody> Function(RequestOptions options) handler) {
    adapter = _ScriptedAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    source = ApiPricingRemoteDataSource(
      dio,
      const ConsoleAppLogger(verbose: false),
    );
  }

  group('the response envelope key', () {
    test('reads items[] from the documented payload', () async {
      // The regression this file exists for. The key was `prices`, and
      // `ApiListEnvelope` treats an absent key as an *empty result set* rather
      // than an error — so the wrong name produced exactly what "this depot
      // has no prices" produces: zero rows, HTTP 200, no exception, no log.
      // Every quotation line rendered unpriced and nothing said why.
      serve((_) async => _json(_specResponse()));

      final rows = await source.fetchPrices(
        depotId: 'c-1',
        materials: ['2400000466'],
      );

      expect(rows, hasLength(1));
      expect(rows.single['material'], '2400000466');
      expect(rows.single['price'], 100.0);
    });

    test('the rows parse into a loaded price, end to end', () async {
      // Pins the key *and* the field names together. Either one being wrong
      // yields an unpriced line, so testing them apart would let a mismatch
      // through.
      serve((_) async => _json(_specResponse()));

      final rows = await source.fetchPrices(
        depotId: 'c-1',
        materials: ['2400000466'],
      );
      final price = MobilePriceMapper.fromJson(rows.single);

      expect(price.state, PricingState.loaded);
      expect(price.price, 100.0);
      expect(price.currency, 'USD');
      expect(price.material, '2400000466');
    });

    test('an empty items[] is a real answer, not a failure', () async {
      // `erpAnswered: true` with no items means "this depot has no prices",
      // which the doc requires be distinguishable from "we could not load
      // prices". It must not throw.
      serve((_) async => _json(_specResponse(items: [])));

      expect(
        await source.fetchPrices(depotId: 'c-1', materials: ['X']),
        isEmpty,
      );
    });
  });

  group('the request', () {
    test('repeats the materials key rather than joining them', () async {
      // `?materials=A&materials=B`. Comma-joining arrives as one material named
      // "A,B" and prices nothing.
      serve((_) async => _json(_specResponse(items: [])));

      await source.fetchPrices(
        depotId: 'c-1',
        materials: ['1100000000', '1100000003'],
      );

      final uri = adapter.requests.single.uri;
      expect(uri.queryParametersAll['materials'], ['1100000000', '1100000003']);
      expect(uri.path, contains('/mobile/pricing/depots/c-1'));
    });

    test('no materials means no round trip at all', () async {
      serve((_) async => _json(_specResponse()));

      expect(
        await source.fetchPrices(depotId: 'c-1', materials: []),
        isEmpty,
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('failures', () {
    test('a 404 surfaces the platform error code', () async {
      // `Pricing.DepotNotFound` is deliberately indistinguishable from "not
      // one this caller may see", so the client must branch on the code rather
      // than infer anything from the status alone.
      serve((_) async => _json({
            'type': 'https://docs.isigroup.com.kh/errors/Pricing.DepotNotFound',
            'title': 'Not found.',
            'status': 404,
            'errorCode': 'Pricing.DepotNotFound',
          }, 404));

      await expectLater(
        source.fetchPrices(depotId: 'c-1', materials: ['X']),
        throwsA(isA<ApiException>().having(
          (e) => e.code,
          'code',
          'Pricing.DepotNotFound',
        )),
      );
    });

    test('a SAP failure is an exception, never an empty price list', () async {
      // The distinction the doc insists on: 500 `Sap.*` is "we could not load
      // prices", which must not render the same way as "no prices".
      serve((_) async => _json({
            'errorCode': 'Sap.Unreachable',
            'status': 500,
          }, 500));

      await expectLater(
        source.fetchPrices(depotId: 'c-1', materials: ['X']),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('source diagnostics', () {
    test('unmapped rows still return, so one bad row costs only itself',
        () async {
      // `recordsUnmapped > 0` means the field-name contract is wrong. Those
      // rows carry `price: 0` and a blank currency; the mapper's job is to
      // classify them, not to drop the page.
      serve((_) async => _json(_specResponse(
            items: [
              {'material': 'A', 'price': 100.0, 'currency': 'USD'},
              // An unmapped row as the API describes it.
              {'material': 'B', 'price': 0, 'currency': ''},
            ],
            unmapped: 1,
          )));

      final rows = await source.fetchPrices(
        depotId: 'c-1',
        materials: ['A', 'B'],
      );

      expect(rows, hasLength(2), reason: 'the good row must survive');
      expect(MobilePriceMapper.fromJson(rows.first).state, PricingState.loaded);
    });

    test('erpAnswered:false does not throw and does not fake prices', () async {
      serve((_) async => _json(_specResponse(items: [], erpAnswered: false)));

      expect(
        await source.fetchPrices(depotId: 'c-1', materials: ['X']),
        isEmpty,
      );
    });
  });
}
