import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/remote/api_route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Serves scripted responses so the data source can be driven without a
/// server — the same shape `auth_interceptor_test.dart` uses.
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

/// One depot, shaped exactly as §7.1 documents it.
Map<String, dynamic> _depot(String id) => {
      'id': id,
      'name': 'Steel Depot $id',
      'nameKh': 'ឃ្លាំង $id',
      'code': 'C-$id',
      'contact': 'Sok Dara',
      'phone': '012345678',
      'address': 'Street 271',
      'territory': 'Phnom Penh',
      'territoryType': 'urban',
      'latitude': 11.55,
      'longitude': 104.91,
      'geofenceRadiusOverride': 150.0,
    };

/// One route with a single stop, per §7.2.
Map<String, dynamic> _route(String id, {required String depotId}) => {
      'id': id,
      'name': 'Route $id',
      'repId': 'rep-1',
      'repName': 'Chan Dara',
      'territory': 'Phnom Penh',
      'visitDate': '2026-08-20T00:00:00Z',
      'plannedStart': '2026-08-20T08:00:00Z',
      'plannedEnd': '2026-08-20T17:00:00Z',
      'status': 'inProgress',
      'stops': [
        {
          'id': '$id-stop-1',
          'routeId': id,
          'customerId': depotId,
          'sequence': 1,
          'plannedArrival': '2026-08-20T09:00:00Z',
          'plannedDeparture': '2026-08-20T09:30:00Z',
          'status': 'checkedIn',
          'actualArrival': '2026-08-20T09:05:00Z',
          'actualDeparture': null,
        }
      ],
    };

Map<String, dynamic> _envelope(Map<String, dynamic> data) =>
    {'data': data, 'message': null, 'metadata': null};

void main() {
  const scope = RouteSyncScope(repId: 'rep-1', territory: 'Phnom Penh');

  /// Builds a data source whose calls all land on [adapter].
  (ApiRouteRemoteDataSource, _ScriptedAdapter) build(
      Future<ResponseBody> Function(RequestOptions) handler) {
    final adapter = _ScriptedAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    return (ApiRouteRemoteDataSource(dio), adapter);
  }

  group('fetchInitial', () {
    test('parses depots, routes and nested stops out of the envelope',
        () async {
      final (source, _) = build((_) async => _json(
            _envelope({
              'customers': [_depot('cust-1')],
              'routes': [_route('route-1', depotId: 'cust-1')],
              'hasMore': true,
            }),
            200,
          ));

      final page =
          await source.fetchInitial(scope: scope, page: 0, pageSize: 50);

      expect(page.hasMore, isTrue);
      expect(page.depots, hasLength(1));
      expect(page.depots.single.nameKh, 'ឃ្លាំង cust-1');
      expect(page.depots.single.territoryType, TerritoryType.urban);
      expect(page.depots.single.geofenceRadiusOverride, 150.0);

      expect(page.routes, hasLength(1));
      final route = page.routes.single;
      // The route's real execution state, not a hardcoded default — this is
      // the bug §7.2 calls out by name.
      expect(route.status, RouteStatus.inProgress);
      expect(route.stops, hasLength(1));
      expect(route.stops.single.status, VisitStatus.checkedIn);
      expect(route.stops.single.actualArrival, isNotNull);
      expect(route.stops.single.actualDeparture, isNull);
      // The stop joined to the flat depot list by `depotId`.
      expect(route.stops.single.depot.id, 'cust-1');
    });

    test('sends territory and converts the 0-based page to the API 1-based one',
        () async {
      final (source, adapter) = build((_) async => _json(
            _envelope({'customers': [], 'routes': [], 'hasMore': false}),
            200,
          ));

      await source.fetchInitial(scope: scope, page: 0, pageSize: 200);

      final query = adapter.requests.single.queryParameters;
      expect(adapter.requests.single.path, ApiEndpoints.visitRoutesEndpoint);
      expect(query['territory'], 'Phnom Penh');
      expect(query['page'], 1, reason: 'page 0 must go out as page 1');
      expect(query['pageSize'], 200);
    });

    test('never sends repId — the server derives it from the bearer token',
        () async {
      final (source, adapter) = build((_) async => _json(
            _envelope({'customers': [], 'routes': [], 'hasMore': false}),
            200,
          ));

      await source.fetchInitial(scope: scope, page: 2, pageSize: 50);

      expect(adapter.requests.single.queryParameters.containsKey('repId'),
          isFalse);
      expect(adapter.requests.single.queryParameters['page'], 3);
    });

    test('omits the territory key entirely when the profile named none',
        () async {
      final (source, adapter) = build((_) async => _json(
            _envelope({'customers': [], 'routes': [], 'hasMore': false}),
            200,
          ));

      await source.fetchInitial(
          scope: const RouteSyncScope(
              repId: 'rep-1', territory: RouteSyncScope.unscoped),
          page: 0,
          pageSize: 50);

      // Sending `territory=` would have the server match a territory literally
      // called "", which returns nothing. Omitting it lets the server scope
      // from the bearer token alone.
      expect(adapter.requests.single.queryParameters.containsKey('territory'),
          isFalse);
    });

    test('an empty route set is a valid page, not an error', () async {
      final (source, _) = build((_) async => _json(
            _envelope({'customers': [], 'routes': [], 'hasMore': false}),
            200,
          ));

      final page =
          await source.fetchInitial(scope: scope, page: 0, pageSize: 50);

      expect(page.routes, isEmpty);
      expect(page.depots, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('drops a stop whose depot is missing rather than failing the page',
        () async {
      final (source, _) = build((_) async => _json(
            _envelope({
              // `cust-1` is referenced by the stop but absent here.
              'customers': [_depot('cust-2')],
              'routes': [_route('route-1', depotId: 'cust-1')],
              'hasMore': false,
            }),
            200,
          ));

      final page =
          await source.fetchInitial(scope: scope, page: 0, pageSize: 50);

      // The route survives; only the unresolvable stop is dropped.
      expect(page.routes, hasLength(1));
      expect(page.routes.single.stops, isEmpty);
    });

    test('a 401 becomes an ApiException carrying the platform error code',
        () async {
      final (source, _) = build((_) async => _json({
            'type': 'https://docs.isigroup.com.kh/errors/Auth.NotAuthenticated',
            'title': 'Unauthorized.',
            'status': 401,
            'errorCode': 'Auth.NotAuthenticated',
            'correlationId': '0HN:1',
          }, 401));

      await expectLater(
        source.fetchInitial(scope: scope, page: 0, pageSize: 50),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCodes.notAuthenticated)
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.error.correlationId, 'correlationId', '0HN:1')),
      );
    });

    test('a transport failure becomes the network sentinel, not a crash',
        () async {
      final (source, _) = build((options) async => throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError));

      await expectLater(
        source.fetchInitial(scope: scope, page: 0, pageSize: 50),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCodes.network)),
      );
    });

    test('a body with no data payload is rejected, not silently empty',
        () async {
      final (source, _) = build((_) async => _json({'message': 'nope'}, 200));

      await expectLater(
        source.fetchInitial(scope: scope, page: 0, pageSize: 50),
        throwsA(isA<Object>()),
      );
    });
  });

  group('fetchDelta', () {
    test('sends territory and the UTC watermark to the delta endpoint',
        () async {
      final (source, adapter) = build((_) async => _json(
            _envelope({'customers': [], 'routes': []}),
            200,
          ));

      await source.fetchDelta(
          scope: scope, since: DateTime.utc(2026, 8, 20, 2, 41, 2));

      final request = adapter.requests.single;
      expect(request.path, ApiEndpoints.visitRoutesDeltaEndpoint);
      expect(request.queryParameters['territory'], 'Phnom Penh');
      expect(request.queryParameters['since'], '2026-08-20T02:41:02.000Z');
    });

    test('treats a body with no hasMore flag as a single complete page',
        () async {
      final (source, _) = build((_) async => _json(
            _envelope({
              'customers': [_depot('cust-1')],
              'routes': [_route('route-1', depotId: 'cust-1')],
            }),
            200,
          ));

      final page =
          await source.fetchDelta(scope: scope, since: DateTime.utc(2026));

      // The delta is documented as a full re-pull of the current scoped set,
      // so an absent flag must not start a paging loop.
      expect(page.hasMore, isFalse);
      expect(page.routes, hasLength(1));
    });
  });
}
