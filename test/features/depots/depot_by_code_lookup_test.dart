import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/features/depots/data/remote/api_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';

/// `GET /depots/by-code/{code}` — the portal-shaped lookup.
///
/// Two things must hold, and the second is the expensive one:
///
///  1. The **portal** envelope and shape are parsed, not the mobile ones. This
///     endpoint answers `{ data, meta }` with `code`/`name`/a nested `address`
///     and a bare `creditLimit` number. Reusing the mobile parser yields a
///     depot with empty fields rather than an error.
///
///  2. **404 and 502 stay distinguishable.** A 404 means the code does not
///     exist, so offering to register the shop is safe. A 502 means the ERP
///     could not be asked — the depot may well exist, and a registration
///     offered there creates a duplicate business partner in SAP.
///
/// See `docs/feature/depot/mobile/mobile.md` §Looking a depot up by code.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

/// The portal response, verbatim from the integration guide.
Map<String, dynamic> _portalBody() => {
      'data': {
        'id': '01a03189-9670-7599-98ac-45ebaf277899',
        'code': 'BP-202608-00002',
        'name': 'Doc Sample Hardware',
        'type': 'Retailer',
        'status': 'Draft',
        'canTrade': false,
        'phone': '012345678',
        'address': {
          'line1': 'Street 271',
          'line2': null,
          'city': 'Phnom Penh',
          'province': null,
          'postalCode': null,
          'latitude': 11.5449,
          'longitude': 104.916,
        },
        'creditLimit': 0.0,
        'creditTermDays': 0,
        'assignedSalesRepId': '019fefcb-0000-0000-0000-000000000001',
        'createdAt': '2026-08-24T02:11:35.707489+00:00',
      },
      'meta': {
        'correlationId': '0HNO1GJO3S25L:00000001',
        'timestamp': '2026-08-24T02:11:35Z',
      },
    };

void main() {
  late _ScriptedAdapter adapter;
  late ApiDepotRemoteDataSource remote;

  void script(Future<ResponseBody> Function(RequestOptions o) handler) {
    adapter = _ScriptedAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    remote = ApiDepotRemoteDataSource(dio);
  }

  test('it calls the portal surface, not /mobile/depots', () async {
    script((o) async => _json(_portalBody(), 200));

    await remote.lookupByCode('6100001234');

    expect(adapter.requests.single.path,
        '${ApiEndpoints.depotsByCodeEndpoint}/6100001234');
    expect(adapter.requests.single.path, isNot(contains('/mobile/')));
  });

  group('200 — found', () {
    test('the portal shape is parsed with its own field names', () async {
      script((o) async => _json(_portalBody(), 200));

      final result = await remote.lookupByCode('BP-202608-00002');

      final found = result as DepotCodeFound;
      expect(found.depot.id, '01a03189-9670-7599-98ac-45ebaf277899');
      // `code`, not `depotCode`.
      expect(found.depot.code, 'BP-202608-00002');
      // `name`, not `shopName`.
      expect(found.depot.name, 'Doc Sample Hardware');
      expect(found.depot.status, 'Draft');
      expect(found.depot.canTrade, isFalse);
    });

    test('address fields are read from the nested object', () async {
      script((o) async => _json(_portalBody(), 200));

      final found = await remote.lookupByCode('x') as DepotCodeFound;

      expect(found.depot.city, 'Phnom Penh');
      expect(found.depot.latitude, 11.5449);
      expect(found.depot.longitude, 104.916);
      expect(found.depot.hasCoordinates, isTrue);
    });

    test('creditLimit is read as a bare number, not { amount, currency }',
        () async {
      script((o) async => _json(_portalBody(), 200));

      final found = await remote.lookupByCode('x') as DepotCodeFound;

      expect(found.depot.creditLimit, 0.0);
      expect(found.depot.creditTermDays, 0);
    });

    test('a 200 with an unusable payload reads as absent, not a broken depot',
        () async {
      script((o) async => _json({'data': null, 'meta': {}}, 200));

      expect(await remote.lookupByCode('x'), isA<DepotCodeAbsent>());
    });
  });

  group('404 vs 502 — the distinction that prevents ERP duplicates', () {
    test('404 is absent, which makes registration safe to offer', () async {
      script((o) async => _json({
            'type': 'https://docs.isigroup.com.kh/errors/Depot.NotFoundByCode',
            'title': 'The requested resource was not found.',
            'status': 404,
            'errorCode': 'Depot.NotFoundByCode',
          }, 404));

      expect(await remote.lookupByCode('nope'), isA<DepotCodeAbsent>());
    });

    test('502 is unavailable — never absent', () async {
      script((o) async => _json({'title': 'Bad Gateway', 'status': 502}, 502));

      final result = await remote.lookupByCode('6100001234');

      expect(result, isA<DepotCodeUnavailable>());
      expect(
        result,
        isNot(isA<DepotCodeAbsent>()),
        reason: 'presenting a 502 as "not found" invites the rep to register a '
            'shop that already exists in SAP, creating a duplicate business '
            'partner that is invisible until someone reconciles the ERP',
      );
    });

    test('the two outcomes are different types, so a caller must handle both',
        () async {
      // The compile-time guarantee, asserted at runtime: an exhaustive switch
      // over the sealed type has no default branch to fall into.
      script((o) async => _json({'status': 502}, 502));
      final unavailable = await remote.lookupByCode('a');

      script((o) async => _json({'status': 404}, 404));
      final absent = await remote.lookupByCode('b');

      String describe(DepotCodeLookup l) => switch (l) {
            DepotCodeFound() => 'found',
            DepotCodeAbsent() => 'absent',
            DepotCodeUnavailable() => 'unavailable',
          };

      expect(describe(unavailable), 'unavailable');
      expect(describe(absent), 'absent');
    });
  });

  test('a 500 is still a transport failure, not a lookup outcome', () async {
    // Only 200/404/502 are answers. Anything else is a real failure and must
    // not be silently turned into "absent".
    script((o) async => _json({'title': 'Server error'}, 500));

    await expectLater(remote.lookupByCode('x'), throwsA(isA<Exception>()));
  });
}
