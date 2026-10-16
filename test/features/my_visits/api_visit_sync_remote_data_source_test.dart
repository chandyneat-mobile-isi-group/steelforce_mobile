import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_api_mapper.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/remote/api_visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';

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

/// A UTC instant, so the serialised form is stable wherever the suite runs.
final _at = DateTime.utc(2026, 8, 20, 9, 15);

CheckInRecordModel _checkIn(String id) => CheckInRecordModel(
      id: id,
      stopId: 'stop-1',
      timestamp: _at,
      latitude: 11.55,
      longitude: 104.91,
      accuracyMeters: 8.5,
      distanceFromDepotMeters: 42.0,
      isMocked: false,
    );

CheckOutRecordModel _checkOut(String id) => CheckOutRecordModel(
      id: id,
      stopId: 'stop-1',
      timestamp: _at,
      latitude: 11.55,
      longitude: 104.91,
      durationMinutes: 25,
      visitSummary: 'Stock counted',
    );

VisitNoteModel _note(String id) => VisitNoteModel(
      id: id,
      stopId: 'stop-1',
      type: VisitNoteType.competitorActivity,
      text: 'Rival banner outside',
      createdAt: _at,
    );

VisitPhotoModel _photo(String id) => VisitPhotoModel(
      id: id,
      stopId: 'stop-1',
      url: '/data/user/0/com.isi.app/cache/photo.jpg',
      caption: 'Shelf',
      takenAt: _at,
    );

VisitPushBatch _batch({
  List<CheckInRecordModel> checkIns = const [],
  List<CheckOutRecordModel> checkOuts = const [],
  List<VisitOrderLineModel> orderLines = const [],
  List<VisitStockUpdateModel> stockUpdates = const [],
  List<VisitReturnModel> returns = const [],
  List<VisitCollectionModel> collections = const [],
  List<VisitNoteModel> notes = const [],
  List<VisitPhotoModel> photos = const [],
}) =>
    VisitPushBatch(
      checkIns: checkIns,
      checkOuts: checkOuts,
      orderLines: orderLines,
      stockUpdates: stockUpdates,
      returns: returns,
      collections: collections,
      notes: notes,
      photos: photos,
    );

Map<String, dynamic> _envelope(Map<String, dynamic> data) =>
    {'data': data, 'message': null, 'metadata': null};

void main() {
  (ApiVisitSyncRemoteDataSource, _ScriptedAdapter) build(
      Future<ResponseBody> Function(RequestOptions) handler) {
    final adapter = _ScriptedAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    return (ApiVisitSyncRemoteDataSource(dio), adapter);
  }

  group('pushVisitData', () {
    test('posts every list to the push endpoint and reads the id split',
        () async {
      final (source, adapter) = build((_) async => _json(
            _envelope({
              'acceptedIds': ['ci-1'],
              'rejectedIds': ['note-1'],
              'syncedAt': '2026-08-20T02:41:02Z',
            }),
            200,
          ));

      final result = await source.pushVisitData(
          _batch(checkIns: [_checkIn('ci-1')], notes: [_note('note-1')]));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, ApiEndpoints.visitPushEndpoint);

      final body = request.data as Map<String, dynamic>;
      // Every documented key is present even when empty, so the payload shape
      // never varies between pushes.
      expect(
          body.keys,
          containsAll(<String>[
            'checkIns',
            'checkOuts',
            'orderLines',
            'stockUpdates',
            'returns',
            'collections',
            'notes',
            'photos',
          ]));

      expect(result.acceptedIds, ['ci-1']);
      expect(result.rejectedIds, ['note-1']);
      expect(result.syncedAt, DateTime.utc(2026, 8, 20, 2, 41, 2));
    });

    test('partial acceptance keeps the refused id out of acceptedIds',
        () async {
      final (source, _) = build((_) async => _json(
            _envelope({
              'acceptedIds': ['ci-1', 'ci-2'],
              'rejectedIds': ['ci-3'],
              'syncedAt': '2026-08-20T02:41:02Z',
            }),
            200,
          ));

      final result = await source.pushVisitData(_batch(
          checkIns: [_checkIn('ci-1'), _checkIn('ci-2'), _checkIn('ci-3')]));

      // One refused row must not strand the other two.
      expect(result.acceptedIds, ['ci-1', 'ci-2']);
      expect(result.rejectedIds, contains('ci-3'));
    });

    test('an id in neither list is simply not accepted, so it stays pending',
        () async {
      final (source, _) = build((_) async => _json(
            _envelope({
              'acceptedIds': ['ci-1'],
              'rejectedIds': <String>[],
              'syncedAt': '2026-08-20T02:41:02Z',
            }),
            200,
          ));

      final result = await source.pushVisitData(
          _batch(checkIns: [_checkIn('ci-1'), _checkIn('ci-2')]));

      expect(result.acceptedIds, ['ci-1']);
      expect(result.acceptedIds, isNot(contains('ci-2')));
    });

    test('a malformed acceptedIds degrades to "nothing accepted", not a crash',
        () async {
      final (source, _) = build((_) async => _json(
            _envelope({'acceptedIds': 'not-a-list', 'syncedAt': null}),
            200,
          ));

      final result =
          await source.pushVisitData(_batch(checkIns: [_checkIn('ci-1')]));

      expect(result.acceptedIds, isEmpty);
    });

    test('a transport failure throws, so no row is ever marked synced',
        () async {
      final (source, _) = build((options) async => throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError));

      await expectLater(
        source.pushVisitData(_batch(checkIns: [_checkIn('ci-1')])),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCodes.network)),
      );
    });

    test('a 4xx on the envelope surfaces its platform error code', () async {
      final (source, _) = build((_) async => _json({
            'type': 'https://docs.isigroup.com.kh/errors/Visit.StopNotFound',
            'title': 'Not found.',
            'status': 404,
            'errorCode': 'Visit.StopNotFound',
            'correlationId': '0HNNSTRGHBJR4:00000001',
          }, 404));

      await expectLater(
        source.pushVisitData(_batch(checkIns: [_checkIn('ci-1')])),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'Visit.StopNotFound')
            .having((e) => e.error.correlationId, 'correlationId',
                '0HNNSTRGHBJR4:00000001')),
      );
    });

    test('re-posting an accepted batch is safe — the same ids come back',
        () async {
      var calls = 0;
      final (source, adapter) = build((_) async {
        calls++;
        return _json(
          _envelope({
            'acceptedIds': ['ci-1'],
            'rejectedIds': <String>[],
            'syncedAt': '2026-08-20T02:41:02Z',
          }),
          200,
        );
      });

      final batch = _batch(checkIns: [_checkIn('ci-1')]);
      final first = await source.pushVisitData(batch);
      final second = await source.pushVisitData(batch);

      // Idempotency is the backend's contract (§3.2); the client's part is to
      // send the same client-generated id both times and accept the repeat.
      expect(calls, 2);
      expect(adapter.requests.map((r) => (r.data as Map)['checkIns'][0]['id']),
          ['ci-1', 'ci-1']);
      expect(second.acceptedIds, first.acceptedIds);
    });
  });

  group('photos (OPEN-1)', () {
    test('are never sent as device-local paths', () async {
      final (source, adapter) = build((_) async => _json(
            _envelope({
              'acceptedIds': ['ci-1'],
              'rejectedIds': <String>[],
              'syncedAt': '2026-08-20T02:41:02Z',
            }),
            200,
          ));

      await source.pushVisitData(
          _batch(checkIns: [_checkIn('ci-1')], photos: [_photo('photo-1')]));

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['photos'], isEmpty,
          reason: 'a local file path must never be sent as a server URL');
    });

    test('stay pending — never reported accepted', () async {
      final (source, _) = build((_) async => _json(
            _envelope({
              // A server that echoed the id back could not mark it synced.
              'acceptedIds': ['ci-1', 'photo-1'],
              'rejectedIds': <String>[],
              'syncedAt': '2026-08-20T02:41:02Z',
            }),
            200,
          ));

      final result = await source.pushVisitData(
          _batch(checkIns: [_checkIn('ci-1')], photos: [_photo('photo-1')]));

      expect(result.rejectedIds, contains('photo-1'));
    });

    test('a photo-only batch makes no request at all', () async {
      final (source, adapter) = build((_) async =>
          fail('a batch with nothing sendable must not hit the network'));

      final result =
          await source.pushVisitData(_batch(photos: [_photo('photo-1')]));

      expect(adapter.requests, isEmpty);
      expect(result.acceptedIds, isEmpty);
      expect(result.rejectedIds, ['photo-1']);
    });
  });

  group('toPushJson field contract', () {
    test('uses the documented camelCase names and real JSON booleans', () {
      final json = _batch(checkIns: [_checkIn('ci-1')]).toPushJson();
      final row = (json['checkIns'] as List).single as Map<String, dynamic>;

      expect(row, {
        'id': 'ci-1',
        'stopId': 'stop-1',
        'timestamp': '2026-08-20T09:15:00Z',
        'latitude': 11.55,
        'longitude': 104.91,
        'accuracy': 8.5,
        'distanceFromDepot': 42.0,
        'isMocked': false,
      });
      // Not the Drift shape: `toRow()` would have written snake_case and 0/1.
      expect(row.containsKey('stop_id'), isFalse);
      expect(row['isMocked'], isA<bool>());
    });

    test('preserves isMocked: true as evidence rather than dropping the row',
        () {
      final mocked = CheckInRecordModel(
        id: 'ci-9',
        stopId: 'stop-1',
        timestamp: _at,
        latitude: 0,
        longitude: 0,
        accuracyMeters: 100,
        distanceFromDepotMeters: 9000,
        isMocked: true,
      );

      final json = _batch(checkIns: [mocked]).toPushJson();
      final row = (json['checkIns'] as List).single as Map<String, dynamic>;

      expect(row['isMocked'], isTrue);
      expect(row['distanceFromDepot'], 9000);
    });

    test('sends enums as their exact documented strings, never integers', () {
      final json = _batch(
        stockUpdates: [
          const VisitStockUpdateModel(
            id: 'sk-1',
            stopId: null,
            depotId: 'depot-7',
            productId: 'p-1',
            productName: 'Rebar 12mm',
            stockLevel: StockLevel.medium,
            notes: '',
          )
        ],
        collections: [
          const VisitCollectionModel(
            id: 'col-1',
            stopId: 'stop-1',
            amount: 250.5,
            method: CollectionMethod.bankTransfer,
            reference: 'TRX-1',
            notes: '',
          )
        ],
        notes: [_note('note-1')],
      ).toPushJson();

      final stock = (json['stockUpdates'] as List).single as Map;
      expect(stock['stockLevel'], 'medium');
      // A depot count carries depotId and a null stopId — the key stays so the
      // distinction is legible server-side.
      expect(stock['stopId'], isNull);
      expect(stock['depotId'], 'depot-7');

      expect(((json['collections'] as List).single as Map)['method'],
          'bankTransfer');
      expect(((json['notes'] as List).single as Map)['type'],
          'competitorActivity');
    });

    test('check-out carries its own client timestamp untouched', () {
      final json = _batch(checkOuts: [_checkOut('co-1')]).toPushJson();
      final row = (json['checkOuts'] as List).single as Map;

      expect(row['timestamp'], '2026-08-20T09:15:00Z');
      expect(row['durationMinutes'], 25);
      expect(row['visitSummary'], 'Stock counted');
    });
  });
}
