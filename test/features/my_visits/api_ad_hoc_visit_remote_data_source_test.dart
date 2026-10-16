import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/remote/api_ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Serves scripted responses so the data source can be driven without a
/// server — the same shape `api_route_remote_data_source_test.dart` uses.
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

Map<String, dynamic> _depot() => {
      'id': 'dep-9',
      'name': 'Toul Kork Yard',
      'nameKh': 'ទួលគោក',
      'code': 'C-9',
      'contact': 'Sok Dara',
      'phone': '012345678',
      'address': 'Street 315',
      'territory': 'Phnom Penh',
      'territoryType': 'urban',
      'latitude': 11.57,
      'longitude': 104.89,
    };

/// The 200 body from §4, verbatim in shape.
Map<String, dynamic> _successBody({bool created = true}) => {
      'success': true,
      'data': {
        'stop': {
          'id': 'stop-adhoc-1',
          'routeId': 'route-1',
          'customerId': 'dep-9',
          'sequence': 1001,
          // The two fields that used to take the whole route sync down.
          'plannedArrival': null,
          'plannedDeparture': null,
          'status': 'pending',
          'actualArrival': null,
          'actualDeparture': null,
          'departureInferred': false,
          'visitSource': 'adHoc',
        },
        'visitDate': '2026-09-29',
        'depot': _depot(),
        'created': created,
      },
      'message': 'Ad hoc visit added to today.',
      'metadata': <String, dynamic>{},
    };

({Dio dio, _ScriptedAdapter adapter}) _client(
    Future<ResponseBody> Function(RequestOptions) handler) {
  final adapter = _ScriptedAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

void main() {
  group('request', () {
    test('posts sk and clientRequestId to the ad hoc endpoint', () async {
      final c = _client((_) async => _json(_successBody(), 200));
      await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');

      final sent = c.adapter.requests.single;
      expect(sent.method, 'POST');
      expect(sent.path, ApiEndpoints.visitAdHocEndpoint);
      expect(sent.data, {
        'sk': '1000123',
        'clientRequestId': 'req-abc',
        'visitDate': null,
      });
    });

    test('visitDate is always null — the server owns the day', () async {
      // A real date is rejected outright as `Visit.AdHocDateInvalid`. Pinned so
      // nobody "helpfully" fills it in when debugging a timezone question.
      final c = _client((_) async => _json(_successBody(), 200));
      await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');

      final sent = c.adapter.requests.single.data as Map;
      expect(sent, contains('visitDate'));
      expect(sent['visitDate'], isNull);
    });

    test('never sends repId — the rep comes from the bearer token', () async {
      final c = _client((_) async => _json(_successBody(), 200));
      await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');

      expect((c.adapter.requests.single.data as Map), isNot(contains('repId')));
    });
  });

  group('response', () {
    test('parses the stop, the depot and the visit date', () async {
      final c = _client((_) async => _json(_successBody(), 200));
      final result = await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');

      expect(result.stop.id, 'stop-adhoc-1');
      expect(result.stop.routeId, 'route-1');
      expect(result.stop.status, VisitStatus.pending);
      expect(result.depot.id, 'dep-9');
      expect(result.depot.name, 'Toul Kork Yard');
      expect(result.visitDate, DateTime(2026, 9, 29));
    });

    test('a null planned window parses instead of throwing', () async {
      // The reason the parser hardening had to ship first: the cast to String
      // threw *inside the route sync transaction*, so one ad hoc stop added by
      // a colleague cost the rep their entire day, not one card.
      final c = _client((_) async => _json(_successBody(), 200));
      final result = await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');

      expect(result.stop.plannedArrival, isNull);
      expect(result.stop.plannedDeparture, isNull);
      expect(result.stop.hasPlannedWindow, isFalse);
    });

    test('reads visitSource, so the card can label itself', () async {
      final c = _client((_) async => _json(_successBody(), 200));
      final result = await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');

      expect(result.stop.visitSource, VisitSource.adHoc);
      expect(result.stop.isAdHoc, isTrue);
      // The 1001+ band is what makes sorting put it last with no special case.
      expect(result.stop.sequence, greaterThanOrEqualTo(1001));
    });

    test('an unrecognised visitSource reads as callPlan, not adHoc', () async {
      // The documented fallback. Reading an unknown origin as adHoc would show
      // a planned call as one the rep invented — the worse way to be wrong.
      final body = _successBody();
      (body['data'] as Map)['stop']['visitSource'] = 'somethingNew';
      final c = _client((_) async => _json(body, 200));

      final result = await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');
      expect(result.stop.visitSource, VisitSource.callPlan);
    });

    test('created:false is carried through, not treated as a failure',
        () async {
      // The server replaying an earlier attempt with the same id. This is
      // idempotency working; the rep has their visit either way.
      final c = _client((_) async => _json(_successBody(created: false), 200));
      final result = await ApiAdHocVisitRemoteDataSource(c.dio)
          .create(sk: '1000123', clientRequestId: 'req-abc');

      expect(result.created, isFalse);
      expect(result.stop.id, 'stop-adhoc-1');
    });
  });

  group('errors', () {
    /// Every refusal must surface its platform code — the codes are the only
    /// thing that can tell these apart, since two share 409 and two share 403.
    for (final (code, status) in const [
      (ApiErrorCodes.visitDepotAlreadyPlanned, 409),
      (ApiErrorCodes.visitAdHocAlreadyExists, 409),
      (ApiErrorCodes.visitDepotNotFound, 404),
      (ApiErrorCodes.visitDepotNotAccessible, 403),
      (ApiErrorCodes.visitRepNotAuthorized, 403),
      (ApiErrorCodes.visitAdHocDateInvalid, 400),
      (ApiErrorCodes.visitTerritoryNotAssigned, 422),
      (ApiErrorCodes.visitAdHocNotAllowed, 422),
    ]) {
      test('$code ($status) arrives as an ApiException carrying its code',
          () async {
        final c = _client((_) async => _json({
              'errorCode': code,
              'title': 'Refused',
              'detail': 'for developers',
              'correlationId': 'corr-1',
            }, status));

        await expectLater(
          ApiAdHocVisitRemoteDataSource(c.dio)
              .create(sk: '1000123', clientRequestId: 'req-abc'),
          throwsA(isA<ApiException>()
              .having((e) => e.error.code, 'code', code)
              .having((e) => e.error.statusCode, 'statusCode', status)),
        );
      });
    }

    test('a 200 with an unreadable body is a ServerException, not a success',
        () async {
      // The queue must not treat this as delivered: the visit may well exist,
      // and only a replay can tell us.
      final c = _client((_) async => _json({
            'success': true,
            'data': {'visitDate': '2026-09-29'},
          }, 200));

      await expectLater(
        ApiAdHocVisitRemoteDataSource(c.dio)
            .create(sk: '1000123', clientRequestId: 'req-abc'),
        throwsA(isA<ServerException>()),
      );
    });

    test('a transport failure arrives as an ApiException', () async {
      final c = _client((options) async => throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 1), requestOptions: options));

      await expectLater(
        ApiAdHocVisitRemoteDataSource(c.dio)
            .create(sk: '1000123', clientRequestId: 'req-abc'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
